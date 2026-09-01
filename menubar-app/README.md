# menubar-app

The SwiftUI menu bar app. Owns the blocklist, the asymmetric-friction
rules, and pushes updates to the extension over a local Unix domain
socket that `native-host/` connects to (Firefox/Chrome) or a loopback-
only TCP connection the Safari extension dials into (Safari) — see
`docs/PROTOCOL.md`.

Built as a Swift Package (`swift build`/`swift run` — fast dev loop,
still works for everything except the Safari extension target). As of
Safari support it's *also* an Xcode project, generated from
`project.yml` by `xcodegen` (`scripts/generate-xcode-project.sh`) —
needed because Safari Web Extensions must ship as an App Extension
bundle embedded in a container app, and Swift Package Manager can't
build that product type. `YTRestrictor.xcodeproj` itself is gitignored
and regenerated on demand; `project.yml` is the committed source of
truth for anything Xcode-specific — never hand-edit the `.xcodeproj`.
For real, "installed" use it's packaged into a proper `.app` bundle and
run under `launchd` — see "Installing as a background service" below.

- `Sources/YTRestrictor/Blocklist.swift` — the data shape (channel
  names, video IDs, keywords), matching `shared/blocklist.example.json`.
  Also compiled into the Safari extension target (see `project.yml`) so
  it can decode the same shape without a second copy.
- `AppPaths.swift` — where everything lives on disk for Firefox/Chrome,
  including the socket path (must match `native-host/src/socket-path.js`).
- `SafariRelayPort.swift` — the Safari counterpart: the loopback port
  number both `SafariLocalRelayServer.swift` (this target) and
  `SafariExtension/SafariWebExtensionHandler.swift` (the sandboxed
  extension target) agree on. Compiled into both targets (see
  `project.yml`) so there's one source of truth for it.
- `BlocklistStore.swift` — the live blocklist + JSON persistence. Adds
  apply instantly; removals are delegated to `FrictionController`.
  Persists to `AppPaths.blocklistFile` (Firefox/Chrome) — Safari reads
  the in-memory `blocklist` property live over the loopback relay
  below, no separate file.
- `FrictionController.swift` — the asymmetric-friction rule itself:
  pending removals wait out an owner-configurable delay (default 30
  min) and can be cancelled any time before they apply.
- `MessagingServer.swift` — the Unix-socket server (`Network.framework`)
  that native-host connects to (Firefox/Chrome only).
- `HeartbeatMonitor.swift` — tracks when the extension last checked in,
  fed by all three browsers' transports.
- `SafariLocalRelayServer.swift` — the Safari counterpart to
  `MessagingServer.swift`: a loopback-only TCP listener
  (`SafariRelayPort.swift`) the sandboxed Safari extension target
  connects to once per `beginRequest()`, since there's no socket
  message to listen for on that side — see `docs/PROTOCOL.md`'s
  "Safari's transport".
- `FirefoxEnforcer.swift` / `SafariEnforcer.swift` — each knows how to
  find and quit exactly one browser, nothing else.
- `EnforcementController.swift` — every 30s, if a browser is running and
  the heartbeat has gone stale (5 min, not owner-configurable), quits it.
- `AppCoordinator.swift` — the one place that constructs and wires all
  of the above together (deliberately not `YTRestrictorApp.init()` —
  see its doc comment for why that's unsafe with `@StateObject`).
- `ContentView.swift` — the menu bar popover UI, including the typed
  "retype the exact value" removal confirmation and the heartbeat status
  line.
- `YTRestrictorApp.swift` — entrypoint (`MenuBarExtra`).
- `SafariExtension/` — the Safari Web Extension App Extension target's
  own native code (not part of the `YTRestrictor` app target — see
  "Safari Web Extension" below):
  - `SafariWebExtensionHandler.swift` — the one entry point Safari calls
    into (`beginRequest`); connects to `SafariLocalRelayServer` over
    loopback TCP for the heartbeat + blocklist round trip.
  - `Info.plist` — the `NSExtension` declaration Safari requires.

## Running it locally

```
swift build          # or: swift run
.build/debug/YTRestrictor
```

A shield icon appears in the menu bar. Click it to open the blocklist
editor. No Dock icon, no window — this is intentional
(`NSApp.setActivationPolicy(.accessory)` in the app init). This plain
`swift build`/`swift run` path never includes the Safari extension —
use the Xcode project below for that.

## Testing the full pipe (extension ↔ native-host ↔ this app)

1. Run this app (`swift run`, from this directory).
2. Make sure the native messaging host is installed:
   `./scripts/install-native-host.sh` (from the repo root).
3. Load/reload the extension in Firefox (see repo root README).
4. Add a channel/video/keyword in the menu bar popover — it should
   apply instantly and, within a moment, whatever you added should
   start getting blocked in Firefox (open the Browser Console to watch
   `[YT Restrictor messaging] received blocklist update` log).
5. Try removing something you just added: you'll be asked to retype the
   exact value, then it shows up under "Pending removals" with a
   countdown and a Cancel button. It only actually leaves the blocklist
   (and stops being enforced) once that countdown finishes. Turn the
   "Removal delay" stepper down while testing so you don't have to wait
   the real default out.

To stop: click the app's "Quit YouTube Restrictor" button in the popover
(there's no Dock icon to quit from, and no menu bar right-click menu —
just the popover button).

## Heartbeat enforcement (Phase 5)

The popover shows a status line: a green dot + "Extension connected —
last checked in Xs ago" normally, or an orange dot + a warning once the
extension hasn't checked in for 5 minutes. If Firefox is running at that
point, the app quits it (gracefully first, then force-quits ~3s later if
it's still around — see `FirefoxEnforcer.swift`) and keeps re-checking
every 30s. This isn't owner-configurable (no stepper for it), matching
`INIT.md`'s Phase 5 spec.

To test without waiting 5 real minutes: temporarily lower
`HeartbeatMonitor.staleAfter` (e.g. to 15s), `swift run`, open Firefox
with the extension loaded, then quit Firefox yourself and relaunch it
without the extension running (or just watch the popover go orange on
its own once you close the tab/browser). Remember to change
`staleAfter` back before committing.

## Safari Web Extension

Safari Web Extensions can't be loaded standalone the way Firefox's
temporary add-ons or Chrome's unpacked extensions can — they have to be
an App Extension target inside a signed, native macOS app bundle, built
via Xcode. That app is `YTRestrictor` itself. This needs full Xcode
(not just Command Line Tools) and a one-time signing setup; Firefox and
Chrome are unaffected either way and need none of this.

**One-time setup:**

1. Install Xcode from the App Store if you haven't already, then:
   ```
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license
   ```
   (First launch may also need `sudo xcodebuild -runFirstLaunch`.)
2. Install `xcodegen` (generates the Xcode project from `project.yml` —
   see that file's header comment for why a plain `.xcodeproj` isn't
   committed):
   ```
   brew install xcodegen
   ```
3. Find your Team ID: Xcode → Settings → **Accounts** → sign in with
   your Apple ID if you haven't already (a free "Personal Team" is
   enough — no paid Apple Developer Program membership needed for local
   use, since this never goes through the App Store) → your team name
   shows the ID in parentheses, e.g. "Stage Erdman (Personal Team)
   (ABCD123456)".
4. Put that ID in `project.yml`'s top-level `settings.base.DEVELOPMENT_TEAM`
   (currently Stage's own team ID — replace it with yours if you're
   building this for yourself). This has to be baked into `project.yml`
   itself, not picked once in Xcode's Signing & Capabilities GUI,
   because `xcodegen generate` regenerates the whole `.xcodeproj` from
   `project.yml` on every build (`scripts/generate-xcode-project.sh`
   runs before every `scripts/build.sh` and every
   `scripts/package-menubar-app-xcode.sh`) — a GUI-only team selection
   gets silently wiped out on the very next regenerate.
5. Generate the project and build it once to confirm signing works:
   ```
   ../scripts/generate-xcode-project.sh
   open YTRestrictor.xcodeproj
   ```
   Then ▶ Run from Xcode — you should see the same shield icon in the
   menu bar as `swift run` produces, and no signing errors. **Stop it
   from Xcode's own Stop button (■) before continuing** — a process
   launched via Xcode's ▶ stays attached to its debugger and won't quit
   from a plain `kill`/⌘Q if you forget this, which just leaves a
   second, harmless-but-confusing shield icon running (ask if you ever
   see two icons and aren't sure why).

**Enabling the extension in Safari:**

1. Safari → Settings → **Advanced** → turn on "Show features for web
   developers" if you haven't already, then Safari → Settings →
   **Developer** → turn on **Allow Unsigned Extensions** (needed for a
   locally-built, non-notarized extension — the same category of step
   as Zen's `xpinstall.signatures.required` policy override, just done
   through Safari's own UI instead of a policy file; see
   `docs/HOW-IT-WORKS.md` for why there's no lockdown-equivalent here).
   This resets every time Safari restarts, same as Firefox's temporary
   add-on install.
2. Safari → Settings → **Extensions** → check the box next to "YouTube
   Restrictor" to turn it on, and grant it permission for
   `youtube.com` (and "All Websites" if you want embed detection on
   other sites too, matching what the extension already requests).
3. Open a YouTube tab and check the Web Inspector console
   (Safari → Settings → Advanced → "Show features for web developers",
   then right-click the page → Inspect Element → Console) for
   `[YT Restrictor]` log lines, same as the Firefox/Chrome dev flow.

**Rebuilding after code changes:** re-run
`../scripts/generate-xcode-project.sh` (picks up any `shared/` or
`project.yml` changes) and build again from Xcode, or use
`../scripts/package-menubar-app-xcode.sh` for a one-shot Release build
(see "Installing as a background service" below for wiring that into
the LaunchAgent).

## Installing as a background service (Phase 6)

```
../scripts/install-launch-agent.sh
```

This packages a real `.app` bundle (`build/YTRestrictor.app`, hand-
assembled from a `swift build -c release` output — see
`../scripts/package-menubar-app.sh`) and registers it as a `LaunchAgent`
at `~/Library/LaunchAgents/com.stage-ria.ytrestrictor-app.plist` with
`RunAtLoad` (starts at login) and `KeepAlive` (relaunches automatically
if it's ever killed — crash, force-quit, or even the popover's own Quit
button). Logs go to
`~/Library/Application Support/YTRestrictor/logs/{stdout,stderr}.log`.

This default packaging has no Safari extension in it (plain SPM build,
no signing needed) — if you've done the Safari setup above and want the
installed background app to include it too, pass `--xcode` instead:

```
../scripts/install-launch-agent.sh --xcode
```

which builds via `xcodebuild` (`../scripts/package-menubar-app-xcode.sh`,
real code signing, requires the one-time Xcode setup above) and installs
that build to the same path instead. Either way the LaunchAgent itself
works identically — only where `build/YTRestrictor.app` comes from
differs.

Verified: `kill -9` on the running process gets it relaunched by
`launchd` within a couple of seconds, with the socket back up.

**This is intentional, not a bug** — see `CLAUDE.md`'s asymmetric-
friction principle. The only sanctioned way to fully and permanently
remove it (you are always the ultimate authority over your own machine):

```
launchctl unload ~/Library/LaunchAgents/com.stage-ria.ytrestrictor-app.plist
rm ~/Library/LaunchAgents/com.stage-ria.ytrestrictor-app.plist
rm -rf build/YTRestrictor.app
```

While developing, prefer `swift run` (plain process, no relaunch) over
fighting the installed LaunchAgent — or `launchctl unload` the plist
first if you need to test against the packaged `.app` without it coming
back on its own.
