# How this works

A short architecture overview for whoever's touching this code next
(most likely Stage). Read `INIT.md` and `CLAUDE.md` first for the *why*
— this is just the *how*, tying the three components together. Each
component also has its own README with file-by-file detail:
`extension/` (none yet — code is small and self-descriptive),
`native-host/README.md`, `menubar-app/README.md`.

## The three processes, at runtime

```
Firefox/Zen                 native-host                  menubar-app
┌───────────────┐  stdio    ┌──────────────┐   Unix      ┌──────────────┐
│  extension     │◄────────►│  host.js     │◄──socket───►│  YTRestrictor │
│  (content +    │  native   │  (spawned    │  (owner's   │  (SwiftUI,   │
│  background    │  messaging│  per session │  local      │  menu bar    │
│  scripts)      │  protocol │  by Firefox) │  machine    │  only)       │
└───────────────┘           └──────────────┘  only)      └──────────────┘
```

- The **extension** runs inside the browser. It detects YouTube players
  (native pages and third-party embeds), matches them against a
  blocklist it keeps in browser storage, and blocks matches locally —
  it never waits on a round-trip to the menu bar app before enforcing.
- **`native-host/`** exists only because Firefox's native-messaging API
  requires a subprocess with a specific stdio framing (4-byte length
  prefix + JSON). Firefox spawns a fresh one per session. It has zero
  blocklist logic — it just relays bytes between that stdio pipe and a
  Unix domain socket.
- **`menubar-app/`** is a normal long-running macOS process
  (`LSUIElement`, no Dock icon) that listens on that same Unix socket.
  It's the one place blocklist state actually lives (JSON on disk —
  see `menubar-app/AppPaths.swift`), and the one place the
  asymmetric-friction rule (`FrictionController.swift`) is enforced.

Message shapes for the stdio/socket link are in `docs/PROTOCOL.md`.
Both directions are "fire and forget" JSON, not request/response.

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
- **Native messaging host manifest**: `~/Library/Application
  Support/Mozilla/NativeMessagingHosts/com.stage_ria.ytrestrictor.json`,
  written by `scripts/install-native-host.sh`. Points at a generated
  wrapper script (`native-host/manifest/run-host.sh`) that hardcodes an
  absolute `node` path, since Firefox spawns native-messaging hosts
  with a minimal environment that may not have Homebrew's `node` on
  `PATH`.
- **LaunchAgent plist**:
  `~/Library/LaunchAgents/com.stage-ria.ytrestrictor-app.plist`.
- **Firefox/Zen policy**: `/Applications/Zen.app/Contents/Resources/
  distribution/policies.json` — lives *inside the app bundle*, so a Zen
  update that replaces the bundle wipes it; re-run
  `scripts/install-policy.sh` after any Zen update.

## Build order, if you're picking this up cold

`INIT.md` section 3 has the authoritative phase list. In short: extension
detection → extension blocking → native-host → menu bar app CRUD +
friction → heartbeat enforcement → launchd packaging → policy lockdown →
this doc. Each phase was its own commit; `git log --oneline` roughly
maps to that order if you want to see how a piece was built up
incrementally rather than reading it fully-formed.
