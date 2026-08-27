# menubar-app

The SwiftUI menu bar app. Owns the blocklist, the asymmetric-friction
rules, and pushes updates to the extension over a local Unix domain
socket that `native-host/` connects to — see `docs/PROTOCOL.md`.

Currently a Swift Package (no Xcode project yet — only the Command Line
Tools were available when this was built, and `swift build`/`swift run`
is a faster test loop anyway). Phase 6 will wrap this in a proper `.app`
bundle for `launchd`/`LSUIElement` packaging.

- `Sources/YTRestrictor/Blocklist.swift` — the data shape (channel
  names, video IDs, keywords), matching `extension/blocklist.example.json`.
- `AppPaths.swift` — where everything lives on disk, including the
  socket path (must match `native-host/src/socket-path.js`).
- `BlocklistStore.swift` — the live blocklist + JSON persistence. Adds
  apply instantly; removals are delegated to `FrictionController`.
- `FrictionController.swift` — the asymmetric-friction rule itself:
  pending removals wait out an owner-configurable delay (default 30
  min) and can be cancelled any time before they apply.
- `MessagingServer.swift` — the Unix-socket server (`Network.framework`)
  that native-host connects to.
- `HeartbeatMonitor.swift` — tracks when the extension last checked in.
- `FirefoxEnforcer.swift` — knows how to find and quit Firefox, nothing
  else.
- `EnforcementController.swift` — every 30s, if Firefox is running and
  the heartbeat has gone stale (5 min, not owner-configurable), quits it.
- `AppCoordinator.swift` — the one place that constructs and wires all
  of the above together (deliberately not `YTRestrictorApp.init()` —
  see its doc comment for why that's unsafe with `@StateObject`).
- `ContentView.swift` — the menu bar popover UI, including the typed
  "retype the exact value" removal confirmation and the heartbeat status
  line.
- `YTRestrictorApp.swift` — entrypoint (`MenuBarExtra`).

## Running it locally

```
swift build          # or: swift run
.build/debug/YTRestrictor
```

A shield icon appears in the menu bar. Click it to open the blocklist
editor. No Dock icon, no window — this is intentional
(`NSApp.setActivationPolicy(.accessory)` in the app init).

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
