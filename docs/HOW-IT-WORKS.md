# How this works

A short architecture overview for whoever's touching this code next
(most likely Stage). Read `INIT.md` and `CLAUDE.md` first for the *why*
— this is just the *how*, tying the pieces together. Each component
also has its own README with file-by-file detail: `native-host/README.md`,
`menubar-app/README.md`. `extension-firefox/`, `extension-chrome/`, and
`extension-safari/` don't have their own — their code is `shared/`,
described below.

## The processes, at runtime

```
Firefox/Zen              native-host                menubar-app
┌──────────────┐  stdio  ┌──────────────┐  Unix     ┌───────────────┐
│  extension    │◄──────►│  host.js     │◄─socket──►│  YTRestrictor  │
│  (content +   │ native  │  (spawned    │ (owner's  │  (SwiftUI,    │
│  background   │messaging│  per session │  local    │  menu bar     │
│  page)        │protocol │  by Firefox) │  machine) │  only)        │
└──────────────┘         └──────────────┘           └───────┬───────┘
                                                              │
Chrome                    native-host                        │ same
┌──────────────┐  stdio  ┌──────────────┐  Unix               │ Unix
│  extension    │◄──────►│  host.js     │◄─socket──────────────┤
│  (content +   │ native  │  (spawned    │                     │
│  service      │messaging│  per session │                     │
│  worker)      │protocol │  by Chrome)  │                     │
└──────────────┘         └──────────────┘                     │
                                                                 │
Safari                    SafariWebExtensionHandler              │
┌──────────────┐ sendNat. ┌──────────────┐  App Group          │
│  extension    │◄────────►│  .appex,     │◄─shared files───────┘
│  (content +   │iveMessage│  sandboxed,  │  (safari-heartbeat.json,
│  service      │ (request/│  embedded in │   safari-blocklist.json —
│  worker)      │ response │  YTRestrictor│   not a socket, see
│               │  only)   │  .app)       │   docs/PROTOCOL.md)
└──────────────┘          └──────────────┘
```

- **The extension** runs inside the browser. It detects YouTube players
  (native pages and third-party embeds), matches them against a
  blocklist it keeps in browser storage, and blocks matches locally —
  it never waits on a round-trip to the menu bar app before enforcing.
  There are three of these — `extension-firefox/` (Manifest V2),
  `extension-chrome/` (Manifest V3), and `extension-safari/`
  (Manifest V3) — sharing one detect/match/block/messaging codebase,
  `shared/`, described below.
- **`native-host/`** exists only because Firefox/Chrome's native-
  messaging APIs require a subprocess with a specific stdio framing
  (4-byte length prefix + JSON). Each browser spawns its own fresh
  instance per session, reading its own separate manifest registration
  (Firefox's and Chrome's `NativeMessagingHosts` directories don't
  overlap) — but it's the same `host.js` either way. It has zero
  blocklist logic; it just relays bytes between that stdio pipe and a
  Unix domain socket. **Safari has no equivalent** — see below.
- **`menubar-app/`** is a normal long-running macOS process
  (`LSUIElement`, no Dock icon) that listens on that same Unix socket,
  for Firefox and Chrome at once — nothing about that socket is
  browser-specific. It's the one place blocklist state actually lives
  (JSON on disk — see `menubar-app/AppPaths.swift`), and the one place
  the asymmetric-friction rule (`FrictionController.swift`) is
  enforced. As of Safari support, `menubar-app/` is also the **container
  app** for the Safari Web Extension — see below — so it's now an Xcode
  project (`menubar-app/project.yml`, generated into
  `YTRestrictor.xcodeproj` by `xcodegen`), not pure Swift Package
  Manager, though `swift build`/`swift run` still work for iterating on
  everything except the Safari extension target itself (SPM can't build
  App Extension bundle products).

Message shapes for the stdio/socket link (Firefox, Chrome) and the App
Group file relay (Safari) are both in `docs/PROTOCOL.md`. Firefox/Chrome
messages are "fire and forget" JSON, not request/response. Safari's are
necessarily request/response — see `docs/PROTOCOL.md`'s "Safari's
transport" section for why, and what that changes about *when*
blocklist updates actually arrive.

## Why Safari needed a different mechanism, not just a third copy

Safari Web Extensions are a genuinely different beast from Firefox's
and Chrome's, not just a third manifest dialect:

1. **No spawned host process.** Firefox and Chrome each spawn
   `native-host/host.js` fresh per session and talk to it over stdio.
   Safari doesn't support this at all — the only native-messaging API
   it implements is one-shot `browser.runtime.sendNativeMessage()`,
   which the OS routes straight into a Swift method
   (`SFSafariExtensionHandler.beginRequest()`) inside the extension's
   own App Extension bundle. There's nothing to register in a
   `NativeMessagingHosts` directory for Safari.
2. **The extension's native code is sandboxed.** Safari Web Extensions
   require `com.apple.security.app-sandbox = true` — unlike
   `native-host/` and `menubar-app/`, which are deliberately
   unsandboxed so they can open a plain Unix domain socket wherever
   they like. A sandboxed process can't reach
   `~/Library/Application Support/YTRestrictor/host.sock`. The
   Apple-sanctioned way for a sandboxed extension and its container app
   to share data is an **App Group** shared container — a plain
   directory both processes can read/write, not a live IPC channel — so
   the relay is two small JSON files, not a socket. Details in
   `docs/PROTOCOL.md`.
3. **Must ship embedded inside a container app.** Safari Web Extensions
   can't be loaded standalone the way Firefox's temporary add-ons or
   Chrome's unpacked extensions can — they have to be an App Extension
   target inside a native macOS app bundle, built via Xcode. Per the
   architecture decision made when this was added, `menubar-app/` *is*
   that container app now, rather than introducing a fourth
   always-running process just to host it.

## Sharing one codebase between three extensions

`shared/` holds every file that doesn't need to differ between browsers:
`detect/`, `match/`, `block/`, `notify/`, `messaging/`, `controller.js`,
`background.js`. `scripts/sync-shared-extension-sources.sh` copies it
into `extension-firefox/src/`, `extension-chrome/src/`, and
`extension-safari/src/` verbatim — loaded extensions are self-contained
directories, so a browser can't reach a file living outside its own
root, meaning `shared/` can't be referenced in place and has to be
physically duplicated in before any of the three loads or gets
packaged. For Safari, that same `src/` copy also becomes the Safari Web
Extension App Extension target's `Resources/` at Xcode build time — same
files, just consumed by `xcodebuild` instead of loaded straight off disk
by the browser. **`shared/` is the only place to edit this logic** —
`scripts/build.sh` re-syncs before every build, and the three copies are
not meant to ever diverge.

Only four files needed to change to become browser-agnostic: they used
to call Firefox's `browser.*` API directly, which doesn't exist in
Chrome (Chrome only defines `chrome.*`). `shared/runtime-shim.js`
(loaded first, everywhere) sets `globalThis.ytRestrictorRuntime` to
whichever of the two is actually defined — Safari also defines
`browser.*`, so it takes the same branch as Firefox here — and
`controller.js`/`detect/embed-scan.js`/`messaging/native-client.js`/
`messaging/oembed-resolver.js` call `ytRestrictorRuntime.*` instead.
Everything else (`detect/youtube-native.js`, `match/`, `block/`,
`notify/`) is pure DOM/logic with no runtime-API calls, so it's
identical on all three browsers with zero changes. `native-client.js`
additionally branches at runtime on whether `connectNative` exists
(Firefox/Chrome: yes, Safari: no) — see `docs/PROTOCOL.md`'s "Safari's
transport" section — rather than needing a fourth, Safari-only copy of
that file.

The one thing that couldn't be unified into a shared file: **the
background entry point.** Firefox's MV2 `"background": {"scripts": [...]}`
loads several files sharing one persistent global scope; Manifest V3
requires a single `"service_worker"` entry instead, so
`extension-chrome/service-worker.js` and `extension-safari/service-worker.js`
(deliberately *not* under `src/`, since the sync script wipes and
repopulates that directory) do `importScripts()` on the same shared
files Firefox's manifest lists directly. The two MV3 service-worker
files are byte-for-byte identical to each other.

**Known Chrome/MV3 limitation:** Chrome kills the service worker after
~30s idle, which drops the native-messaging port with it. The shared
heartbeat code uses the `alarms` API (not `setInterval`, which wouldn't
survive that) to wake the worker back up every 60s and reconnect — so
heartbeats still go out reliably, but a `blocklist-update` pushed by the
menu bar app while the worker's asleep won't arrive until the next
wake, up to ~60s later. Firefox's persistent background page has no
such gap. **Safari has a related but structurally different limitation:
every blocklist update takes up to ~60s to arrive, every time, not just
when a worker happens to be asleep** — see `docs/PROTOCOL.md`'s
heartbeat and "Safari's transport" sections.

## Why it's hard to turn off, and why that's still safe

Two independent mechanisms, both reversible by hand, per `CLAUDE.md`'s
"owner is the ultimate authority" principle:

1. **`policies.json` force-install** (`scripts/install-policy.sh`,
   Phase 7). Firefox-family browsers read `Contents/Resources/
   distribution/policies.json` inside the app bundle at launch and
   apply `ExtensionSettings` before the user ever gets a say —
   `about:addons` just doesn't render a Remove button for anything
   marked `force_installed`. This targets **Zen Browser**, not release
   Firefox, because force-installing an *unsigned* `.xpi` also requires
   setting `xpinstall.signatures.required: false` via policy, and
   release Firefox hard-blocks that override regardless of what the
   policy says (a Mozilla anti-abuse guardrail with no exception for
   local policies). Zen already ships with signature enforcement off by
   default, so it works there without needing Firefox Developer
   Edition or going through Mozilla's AMO signing process just to
   self-distribute a personal tool. Removing it is one file delete
   (see README's "Uninstalling completely").
2. **`launchd` `KeepAlive`** (`scripts/install-launch-agent.sh`,
   Phase 6). If the menu bar app is killed — crash, force-quit, `kill
   -9` — `launchd` restarts it within a couple seconds. Combined with
   the heartbeat (below), this means "just kill the app and unblock
   things" doesn't work as a bypass. Removing it is `launchctl unload`
   + deleting the plist and `.app` bundle.

Neither mechanism hides anything: the policy file, the LaunchAgent
plist, and the app bundle are all plain files in normal locations, all
visible to Activity Monitor / Finder / `launchctl list` / `about:addons`
like anything else on the machine. The friction is procedural (you have
to know to delete three specific things and mean it), never technical
concealment.

**Chrome has no equivalent of #1 yet.** Chrome's version of a policy-
forced install needs a self-signed `.crx`, a locally-hosted update
manifest, and a policy plist written to `/Library/Managed Preferences`
— root-owned, system-wide, normally an MDM mechanism rather than
something an app bundle ships with the way Zen's `policies.json` does.
That's a meaningfully bigger blast radius than anything scripted so
far, and it's deliberately not built yet — see the "Chrome (not locked
down yet)" section of the root README. Until it exists, the Chrome
extension is removable with one click from `chrome://extensions`, same
as any other unpacked extension.

**Safari has no equivalent of #1 either, and can't, without MDM.** There
is no policy file or local mechanism that force-installs a Safari Web
Extension or hides its toggle in Safari Settings → Extensions — Apple
only offers that via Apple Business/School Manager device-management
profiles, which is out of scope for a single-user personal tool per
`CLAUDE.md` principle 5 (no accounts, no remote admin). The heartbeat
mechanism below is Safari's only enforcement lever, same as Chrome's
today: disabling the extension in Safari Settings doesn't survive
quietly, it gets Safari force-quit instead. Removing the extension
outright just means deleting `YTRestrictor.app` (the same app the owner
would delete to remove the menu bar app entirely) — there's nothing
Safari-specific left over.

## The heartbeat, and why it exists

The extension pings `heartbeat` every 60s regardless of what's playing
— over the native-messaging link for Firefox/Chrome, via
`sendNativeMessage` for Safari (see `docs/PROTOCOL.md`'s "Safari's
transport"). `HeartbeatMonitor` in the menu bar app just tracks "when
did I last hear from the extension" — one shared instance, fed by all
three browsers' transports alike. If Zen is running and 5 minutes pass
with no heartbeat, `EnforcementController` quits Zen via
`FirefoxEnforcer`; the same check runs for Safari via `SafariEnforcer`
(bundle identifier `com.apple.Safari`, quit the same graceful-then-force
way). This exists so that disabling the extension (rather than
uninstalling it, which the policy already blocks for Firefox/Zen) 
doesn't quietly restore unrestricted YouTube access — it forces the
browser closed instead, which is very noticeable. Chrome still has no
enforcement wired up on this axis (heartbeat monitoring, yes;
quit-on-stale, no) — that gap predates Safari support and is unrelated
to it.

This is *not* configurable from the UI (no stepper, unlike the removal
delay) — see `INIT.md` Phase 5. If that's ever revisited, treat it as a
deliberate scope change, not a bug fix.

**Known bug, found while adding Chrome support, not yet fixed:**
`FirefoxEnforcer.swift` hardcodes bundle identifier `org.mozilla.firefox`
— but Phase 7 switched the actual force-installed browser to Zen, whose
real bundle identifier is `app.zen-browser.zen` (confirmed by reading
`/Applications/Zen.app/Contents/Info.plist` directly). `isFirefoxRunning()`
therefore returns `false` whenever Zen (not real Firefox) is what's
open, so `EnforcementController` silently never fires against it. This
predates the Chrome work and is unrelated to it — flagged here rather
than fixed, since fixing it means editing `menubar-app/`. Chrome would
need its own equivalent bundle-ID check (`com.google.Chrome`) added
alongside whatever the Zen fix ends up being, once that's prioritized.

**Known limitation, made more visible by adding Safari, not yet fixed:**
`HeartbeatMonitor` is a single global "when did I last hear a heartbeat
from *any* browser" timestamp, not one per browser. `EnforcementController`
gates its Firefox check on `isFirefoxRunning()`, so today, with only
Firefox and Chrome, a live Chrome heartbeat can mask a dead Firefox one
being open at the same time — `heartbeatMonitor.isStale` reads `false`
(because Chrome just checked in) even though Firefox's own extension
may have silently stopped. Adding Safari as a third source makes this
three-way instead of two-way but doesn't introduce it. Not fixed here
since it means changing `HeartbeatMonitor`/`MessagingServer` to track a
per-source timestamp (tagging each heartbeat with which transport it
arrived over), which is a real design change to code Firefox and Chrome
already depend on — out of scope for "add Safari support." Worth
prioritizing if more than one of these browsers is ever open at once in
practice.

## Asymmetric friction, concretely

`BlocklistStore.swift` applies additions synchronously — no
confirmation, no delay. Removals go through
`FrictionController.swift`: the owner must retype the exact value being
removed, which then sits in a "pending removal" queue with a
countdown (default 30 min, owner-configurable via a plain `Stepper` in
`ContentView.swift` — that control itself is *not* friction-gated)
before it's actually dropped from the blocklist and the update gets
pushed to the extension. Cancelling a pending removal is instant and
always available before the countdown ends. This is the one piece of
UX in the whole project that's deliberately *not* frictionless — see
`CLAUDE.md` principle 3.

## Where state actually lives

- **Blocklist** (source of truth): JSON file under
  `~/Library/Application Support/YTRestrictor/` — see
  `menubar-app/AppPaths.swift` for the exact path. The extension only
  ever holds a cached copy in browser storage, pushed to it via
  `blocklist-update` messages.
- **Socket path**: also under that same Application Support directory —
  must match between `native-host/src/socket-path.js` and
  `menubar-app/AppPaths.swift` (there's no negotiation; both sides hard-
  code it).
- **Native messaging host manifests** — one per browser, both pointing
  at the same generated wrapper script
  (`native-host/manifest/run-host.sh`, which hardcodes an absolute
  `node` path since browsers spawn native-messaging hosts with a
  minimal environment that may not have Homebrew's `node` on `PATH`):
  - Firefox: `~/Library/Application Support/Mozilla/
    NativeMessagingHosts/com.stage_ria.ytrestrictor.json`, written by
    `scripts/install-native-host.sh`.
  - Chrome: `~/Library/Application Support/Google/Chrome/
    NativeMessagingHosts/com.stage_ria.ytrestrictor.json`, written by
    `scripts/install-native-host-chrome.sh`. Chrome's manifest needs the
    extension's ID in `allowed_origins`; for an unpacked extension with
    no `"key"` in `manifest.json`, Chrome derives that ID from the
    extension's absolute install path, which this script computes —
    see the script's own header comment for why that's flagged as
    unverified rather than asserted correct.
- **LaunchAgent plist**:
  `~/Library/LaunchAgents/com.stage-ria.ytrestrictor-app.plist`.
- **Firefox/Zen policy**: `/Applications/Zen.app/Contents/Resources/
  distribution/policies.json` — lives *inside the app bundle*, so a Zen
  update that replaces the bundle wipes it; re-run
  `scripts/install-policy.sh` after any Zen update.
- **App Group shared container (Safari only)**: `~/Library/Group
  Containers/group.com.stage-ria.ytrestrictor/` — holds
  `safari-heartbeat.json` and `safari-blocklist.json`, written/read by
  `menubar-app/SafariExtension/SafariWebExtensionHandler.swift` (the
  sandboxed side) and `menubar-app/Sources/YTRestrictor/
  SafariHeartbeatWatcher.swift` / `BlocklistStore.swift` (the
  unsandboxed side). Both targets declare the same App Group identifier
  in their entitlements — see `menubar-app/project.yml`. This directory
  is separate from `~/Library/Application Support/YTRestrictor/`
  (Firefox/Chrome's blocklist + socket) — Safari can't reach that path
  at all, being sandboxed, so it gets its own.

## Build order, if you're picking this up cold

`INIT.md` section 3 has the authoritative phase list for the original
Firefox/Zen-only build: extension detection → extension blocking →
native-host → menu bar app CRUD + friction → heartbeat enforcement →
launchd packaging → policy lockdown → docs. Each phase was its own
commit; `git log --oneline` roughly maps to that order if you want to
see how a piece was built up incrementally rather than reading it
fully-formed. Chrome support came after all 8 of those phases were
done, as a separate addition: `extension/` was renamed to
`extension-firefox/`, `shared/` was carved out of it, and
`extension-chrome/` was added alongside — core detection/blocking/
native-messaging first, with Chrome's own force-install lockdown
deliberately deferred (see "Why it's hard to turn off" above).

Safari support came after that, as a third addition, and required more
than a third manifest: `extension-safari/` was added to the `shared/`
sync rotation like Chrome was, but `menubar-app/` itself had to become
an Xcode project (`project.yml` → `xcodegen` → `YTRestrictor.xcodeproj`,
alongside the still-working `Package.swift` for non-Safari dev work)
with a second, sandboxed target — Safari Web Extensions must be
embedded inside a native container app, and that app is `YTRestrictor`
itself rather than a fourth standalone process. See "Why Safari needed
a different mechanism, not just a third copy" above for the concrete
reasons `extension-safari/` couldn't just reuse Chrome's native-
messaging plumbing.
