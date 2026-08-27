# How this works

A short architecture overview for whoever's touching this code next
(most likely Stage). Read `INIT.md` and `CLAUDE.md` first for the *why*
— this is just the *how*, tying the pieces together. Each component
also has its own README with file-by-file detail: `native-host/README.md`,
`menubar-app/README.md`. `extension-firefox/` and `extension-chrome/`
don't have their own — their code is `shared/`, described below.

## The processes, at runtime

```
Firefox/Zen                 native-host                  menubar-app
┌───────────────┐  stdio    ┌──────────────┐   Unix      ┌──────────────┐
│  extension     │◄────────►│  host.js     │◄──socket───►│  YTRestrictor │
│  (content +    │  native   │  (spawned    │  (owner's   │  (SwiftUI,   │
│  background    │  messaging│  per session │  local      │  menu bar    │
│  page)         │  protocol │  by Firefox) │  machine    │  only)       │
└───────────────┘           └──────────────┘   only)     └──────┬───────┘
                                                                  │
Chrome                       native-host                         │ same
┌───────────────┐  stdio    ┌──────────────┐   Unix               │ Unix
│  extension     │◄────────►│  host.js     │◄──socket─────────────┘
│  (content +    │  native   │  (spawned    │
│  service       │  messaging│  per session │
│  worker)       │  protocol │  by Chrome)  │
└───────────────┘           └──────────────┘
```

- **The extension** runs inside the browser. It detects YouTube players
  (native pages and third-party embeds), matches them against a
  blocklist it keeps in browser storage, and blocks matches locally —
  it never waits on a round-trip to the menu bar app before enforcing.
  There are two of these — `extension-firefox/` (Manifest V2) and
  `extension-chrome/` (Manifest V3) — sharing one detect/match/block/
  messaging codebase, `shared/`, described below.
- **`native-host/`** exists only because native-messaging APIs require a
  subprocess with a specific stdio framing (4-byte length prefix +
  JSON). Each browser spawns its own fresh instance per session,
  reading its own separate manifest registration (Firefox's and
  Chrome's `NativeMessagingHosts` directories don't overlap) — but
  it's the same `host.js` either way. It has zero blocklist logic; it
  just relays bytes between that stdio pipe and a Unix domain socket.
- **`menubar-app/`** is a normal long-running macOS process
  (`LSUIElement`, no Dock icon) that listens on that same Unix socket,
  for both browsers at once — nothing about it is browser-specific. It's
  the one place blocklist state actually lives (JSON on disk — see
  `menubar-app/AppPaths.swift`), and the one place the asymmetric-
  friction rule (`FrictionController.swift`) is enforced.

Message shapes for the stdio/socket link are in `docs/PROTOCOL.md`.
Both directions are "fire and forget" JSON, not request/response.

## Sharing one codebase between two extensions

`shared/` holds every file that doesn't need to differ between browsers:
`detect/`, `match/`, `block/`, `notify/`, `messaging/`, `controller.js`,
`background.js`. `scripts/sync-shared-extension-sources.sh` copies it
into `extension-firefox/src/` and `extension-chrome/src/` verbatim —
loaded extensions are self-contained directories, so a browser can't
reach a file living outside its own root, meaning `shared/` can't be
referenced in place and has to be physically duplicated in before either
extension loads or gets packaged. **`shared/` is the only place to edit
this logic** — `scripts/build.sh` re-syncs before every build, and the
two copies are not meant to ever diverge.

Only four files needed to change to become browser-agnostic: they used
to call Firefox's `browser.*` API directly, which doesn't exist in
Chrome (Chrome only defines `chrome.*`). `shared/runtime-shim.js`
(loaded first, everywhere) sets `globalThis.ytRestrictorRuntime` to
whichever of the two is actually defined, and
`controller.js`/`detect/embed-scan.js`/`messaging/native-client.js`/
`messaging/oembed-resolver.js` call `ytRestrictorRuntime.*` instead.
Everything else (`detect/youtube-native.js`, `match/`, `block/`,
`notify/`) is pure DOM/logic with no runtime-API calls, so it's
identical on both browsers with zero changes.

The one thing that couldn't be unified into a shared file: **the
background entry point.** Firefox's MV2 `"background": {"scripts": [...]}`
loads several files sharing one persistent global scope; Manifest V3
requires a single `"service_worker"` entry instead, so
`extension-chrome/service-worker.js` (deliberately *not* under `src/`,
since the sync script wipes and repopulates that directory) does
`importScripts()` on the same shared files Firefox's manifest lists
directly.

**Known Chrome/MV3 limitation:** Chrome kills the service worker after
~30s idle, which drops the native-messaging port with it. The shared
heartbeat code uses the `alarms` API (not `setInterval`, which wouldn't
survive that) to wake the worker back up every 60s and reconnect — so
heartbeats still go out reliably, but a `blocklist-update` pushed by the
menu bar app while the worker's asleep won't arrive until the next
wake, up to ~60s later. Firefox's persistent background page has no
such gap. See `docs/PROTOCOL.md`'s heartbeat section.

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

## The heartbeat, and why it exists

The extension pings `heartbeat` over the native-messaging link every
60s regardless of what's playing. `HeartbeatMonitor` in the menu bar app
just tracks "when did I last hear from the extension." If Zen is
running and 5 minutes pass with no heartbeat, `EnforcementController`
quits Zen via `FirefoxEnforcer`. This exists so that disabling the
extension (rather than uninstalling it, which the policy already
blocks) doesn't quietly restore unrestricted YouTube access — it forces
the browser closed instead, which is very noticeable.

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
