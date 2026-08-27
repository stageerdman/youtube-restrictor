# CLAUDE.md

Operating instructions for any agent working in this repository. Read
`INIT.md` first for project context. This file governs *how* to work, not
*what* to build.

## Core principles

1. **Modularity above all.** Three components, three clean boundaries, no
   leaking abstractions between them:
   - The browser extension — knows nothing about how the macOS app is
     implemented; only speaks the native-messaging JSON protocol defined
     in `docs/PROTOCOL.md`. Two browser targets share one detection/
     matching/blocking codebase in `shared/` (browser-agnostic, no
     `browser.*`/`chrome.*` calls outside `shared/messaging/` and
     `shared/runtime-shim.js`), copied into each browser's own
     self-contained extension directory by
     `scripts/sync-shared-extension-sources.sh` (browsers can't load
     files from outside their own extension root, so `shared/` can't be
     referenced in place — always edit there, never in the copies):
     - `extension-firefox/` — Manifest V2, targets Zen Browser (see
       Phase 7 in `INIT.md`).
     - `extension-chrome/` — Manifest V3 (service worker background,
       required by MV3 — see `extension-chrome/service-worker.js`).
   - `native-host/` — the native messaging host binary/script. A thin,
     dumb pipe: stdin/stdout framing per Firefox's native messaging spec,
     forwards messages to/from the macOS app. No blocklist logic lives
     here.
   - `menubar-app/` — the SwiftUI macOS app. Owns the blocklist, owns the
     heartbeat/enforcement logic, owns all UI.
   - Within each component, split further: detection logic, matching
     logic, and UI/presentation should be separate files/modules, each
     independently testable. If a function is doing two of
     {detect, match, block, persist, notify}, split it.
2. **The owner is always the ultimate authority.** Every "hard to disable"
   mechanism must be defeatable by a deliberate, informed action taken
   directly on the owner's own Mac (deleting the LaunchAgent plist, the app
   bundle, and the Firefox policy file). Never build anything that survives
   that, hides from system tools (Activity Monitor, `launchctl list`,
   `about:addons`, Finder), or resists the owner's own access to their own
   machine. This is a self-control tool, not an anti-tamper product aimed
   at a third party — treat that distinction as load-bearing in every design
   decision.
3. **Asymmetric friction, not asymmetric secrecy.** Tightening restrictions
   is instant. Loosening restrictions requires explicit confirmation and a
   delay. Nothing about the tool should be hidden from the person who
   installed it — no obscured settings, no undocumented behavior. Friction
   is achieved through deliberate UX (typed confirmations, cool-down timers),
   never through deception or concealment.
4. **No network calls except what's declared.** The only external dependency
   should be the YouTube Data API (if used, to resolve channel names for
   embeds) and GitHub (for source sync). No telemetry, no analytics, no
   third-party backends. If a future feature seems to need one, stop and
   flag it to the owner before implementing.
5. **Single user, single machine.** No accounts, no sync-across-devices, no
   remote admin. If a request would require this, flag it rather than
   building it.
6. **Plain language in anything Ria or Stage will read.** README sections,
   in-app copy, and commit messages should be understandable without a CS
   background. Code comments can be technical; user-facing text cannot.
7. **Run this repo's own local setup/install scripts without asking first.**
   Scripts that exist in this repo specifically to configure the owner's
   own dev machine for this project — e.g. `scripts/install-native-host.sh`,
   `scripts/install-policy.sh`, `scripts/build.sh` — are local, scoped to
   this project, and trivially reversible (re-run them, or delete the file
   they wrote). Run them proactively as part of finishing a phase instead of
   pausing to confirm. This does not extend to anything outside that
   category: destructive commands, git push/force-push, changes to files
   or system state outside this project's own dev-setup footprint, or
   anything else covered by the general "check before risky actions"
   guidance still needs confirmation as normal.

## Repo layout (expected top-level structure)

```
.
├── INIT.md
├── CLAUDE.md
├── README.md
├── .gitignore
├── docs/
│   ├── PROTOCOL.md          # native-messaging JSON message schema, versioned
│   └── HOW-IT-WORKS.md      # architecture overview
├── shared/                  # detect/match/block/messaging logic, both browsers
│   ├── detect/              # player detection (native + embedded)
│   ├── match/                # blocklist matching logic
│   ├── block/                # playback interruption / placeholder UI
│   ├── messaging/            # native messaging + heartbeat client
│   ├── runtime-shim.js       # picks `browser` (Firefox) vs `chrome` (Chrome)
│   └── background.js
├── extension-firefox/
│   ├── manifest.json        # MV2
│   ├── policies.template.json
│   └── src/                 # populated from shared/, do not edit directly
├── extension-chrome/
│   ├── manifest.json        # MV3
│   ├── service-worker.js    # MV3 background entry point (imports src/*)
│   └── src/                 # populated from shared/, do not edit directly
├── native-host/
│   ├── host.(js|swift)
│   └── manifest/            # NativeMessagingHosts manifest templates, per browser
├── menubar-app/
│   └── YTRestrictor/        # SwiftUI Xcode project
└── scripts/
    ├── build.sh                            # builds everything, see below
    ├── sync-shared-extension-sources.sh    # shared/ -> each extension's src/
    ├── install-native-host.sh              # Firefox native-messaging registration
    ├── install-native-host-chrome.sh       # Chrome native-messaging registration
    └── install-policy.sh                   # installs/updates Zen policies.json
```

Adjust as the project evolves, but keep the boundary between the three
components intact — don't collapse them into one flat directory.

## Git / GitHub sync (mandatory, every session)

- Check `git status` at the start of a session. If this directory isn't a
  git repo yet, run `git init`, add `.gitignore`, and make an initial commit.
- If there's no `origin` remote yet, create the GitHub repo with
  `gh repo create <name> --public --source=. --remote=origin --push`.
  Confirm the intended repo name/account with the owner first if it isn't
  already obvious from context — don't silently invent one.
- After **every** meaningful change (not every single file edit, but every
  logically complete step): `git add -A && git commit -m "<short message>"`
  then `git push`. Don't let uncommitted work pile up across turns.
- Never commit real blocklist data, credentials, API keys, or `.env` files.
  Double-check `git status`/`git diff --stat` before committing if anything
  under those categories could plausibly have been touched.

## Build + report protocol (mandatory, every change)

After every change, in this order:

1. **Build everything relevant to what changed** — don't skip components
   that weren't touched, but do skip a full rebuild of an unrelated
   component if it's slow and clearly unaffected. Concretely:
   - If anything under `shared/` changed, run
     `scripts/sync-shared-extension-sources.sh` before building either
     extension — it's the only thing that copies those edits into
     `extension-firefox/src/` and `extension-chrome/src/`.
   - `extension-firefox/`: run the lint/packaging script (`web-ext lint`,
     `web-ext build`, or equivalent) to confirm the manifest and code are
     valid.
   - `extension-chrome/`: validate `manifest.json` and syntax-check the
     JS (no official MV3 lint CLI in use here — see `scripts/build.sh`
     for what's actually run).
   - `native-host/`: compile/typecheck it.
   - `menubar-app/`: `xcodebuild` (or `swift build`) the SwiftUI app.
2. **Report build status explicitly** — state pass/fail per component, and
   paste the actual error output if something failed. Don't say "should
   work" — say what was actually run and what actually happened.
3. **If the build succeeded and either extension changed at all**, give
   exact, copy-pasteable next steps to get it running, every time, even
   if it seems repetitive. Default instructions to include:

   **Firefox/Zen — temporary/dev install (fastest, resets on restart):**
   1. Open Firefox/Zen and go to `about:debugging#/runtime/this-firefox`
   2. Click "Load Temporary Add-on…"
   3. Select `extension-firefox/manifest.json` from this repo
   4. Confirm the extension appears in the list with no errors

   **Chrome — unpacked install (resets on browser restart unless pinned):**
   1. Open `chrome://extensions`, enable "Developer mode" (top right)
   2. Click "Load unpacked" and select the `extension-chrome/` folder
   3. Confirm it appears in the list with no errors, and note the ID
      shown — needed by `scripts/install-native-host-chrome.sh`

   **If the manifest, permissions, or native messaging host name changed**
   (temporary/unpacked install won't pick these up cleanly — say so
   explicitly and add):
   5. Remove the previously loaded temporary/unpacked extension first
   6. If the native messaging host manifest changed, re-run
      `scripts/install-native-host.sh` (Firefox) and/or
      `scripts/install-native-host-chrome.sh` (Chrome) before reloading

   **If this is a signed/permanent install milestone**, give the actual
   packaging + `about:addons`/`chrome://extensions` install steps for
   that specific point in the project instead of the temporary-install
   steps above.
4. **If the menu bar app changed**, give exact steps to rebuild/relaunch it
   locally (e.g. "quit any running instance from the menu bar icon first,
   then run `scripts/build.sh` and reopen `menubar-app/build/YTRestrictor.app`"),
   and note if a `launchd` reload is needed
   (`launchctl unload/load ~/Library/LaunchAgents/<plist>`).

Never end a turn that changed code without doing steps 1–3 (and 4 if
applicable). If a build step can't be run in the current environment,
say so plainly and explain what the owner needs to run locally instead.

## When something in a request conflicts with these principles

Say so directly and propose the closest in-scope alternative, rather than
quietly building a softened version or quietly building it anyway.
