# INIT.md — YouTube Restrictor

Read this fully before writing any code. Then read `CLAUDE.md` in the repo root
and follow it for the rest of the project's life.

## 1. What this is

A personal self-control tool, similar in spirit to Cold Turkey Blocker, built
by and for its own owner (single-user, own machine, own browser, own consent).
It has two halves:

1. **Firefox extension** — detects YouTube playback anywhere on the web
   (youtube.com, youtu.be, and embedded players on third-party sites), checks
   it against a blocklist (channels / video IDs / keywords), and blocks
   playback when there's a match.
2. **macOS menu bar app** — the single source of truth for the blocklist.
   Holds the blocklist, lets the owner edit it (with deliberate friction:
   confirmation + delay before loosening restrictions, never before
   tightening them), and pushes it to the extension over Firefox's Native
   Messaging protocol. It also runs a heartbeat check: if Firefox is open but
   the extension hasn't checked in for 5 minutes, it closes Firefox, and it
   re-launches itself via `launchd` if killed.

The "hard to disable" property comes from two *legitimate* mechanisms only:

- Firefox **enterprise policy** (`policies.json`) marking the extension as
  `force_installed`, so it can't be removed from `about:addons` without
  editing that policy file directly.
- The heartbeat-kills-browser fallback described above, plus a `launchd`
  `KeepAlive` agent for the menu bar app.

**Explicitly out of scope / not to be built, ever:**
- Anything that hides the app/extension's presence from the OS, from
  `about:addons`, from Activity Monitor, or from the user's own inspection.
- Anything that survives a deliberate, informed macOS-level uninstall (i.e.
  removing the LaunchAgent plist + app bundle + Firefox policy file by hand
  must always fully and permanently remove everything — the owner is always
  the ultimate authority over their own machine).
- Any code that would function as spyware/keylogging, that talks to a remote
  server, that collects analytics, or that touches any browser profile other
  than the owner's own local one.
- Anything that would apply to or affect a browser/machine other than the
  one the owner explicitly configures. No multi-user/remote-admin features.

This is a personal productivity tool. Keep it exactly that scoped.

## 2. Two users of this codebase

Two people work on / use this, and code, comments, commit messages, and the
blocklist config schema should stay legible to both:

- **Ria** — non-engineer background (mindset coaching, physical therapy,
  gymnastics). Cares about: does it actually stop the behavior, is the
  blocklist editing UI simple and fast to use day-to-day.
- **Stage / Vlado** — mechanical engineering + coding background, will do
  most of the low-level implementation work (native messaging host, Swift
  app, launchd, Firefox policy internals).

Practical implication: the menu bar app's UI copy and the README must be
written so a non-engineer can operate the app (edit blocklist, understand
why a change is delayed, understand what the heartbeat does) without needing
to read code.

## 3. High-level plan / build order

Build and ship in this order — each phase should be independently testable
before moving to the next:

1. **Extension core: detection.** Content script detects YouTube players
   (native youtube.com pages via `ytInitialData`, and third-party embeds via
   iframe `src` matching + `MutationObserver` for dynamically injected
   iframes). No blocking yet — just log what it finds to the console.
2. **Extension core: blocking.** Hardcode a small test blocklist
   (channel IDs, keywords, video IDs). When a detected player matches,
   stop playback / remove or replace the player with a blocked-message
   placeholder.
3. **Native messaging host.** Small Node or Swift binary + manifest JSON
   registered under `~/Library/Application Support/Mozilla/NativeMessagingHosts/`.
   Extension connects via `runtime.connectNative`, receives blocklist
   updates, sends heartbeats.
4. **macOS menu bar app (SwiftUI, `LSUIElement` menu bar only).**
   - Blocklist CRUD UI (channels / video IDs / keywords).
   - Persists blocklist locally (plain JSON, human-readable, git-friendly
     if the owner wants to version it).
   - Pushes blocklist to extension via the native messaging host whenever
     it changes.
   - **Asymmetric friction**: tightening the blocklist (adding an entry) is
     instant; loosening it (removing an entry, or disabling enforcement)
     requires typed confirmation + a delay (owner-configurable, default
     e.g. 30–60 min) before it takes effect.
5. **Heartbeat + enforcement.** App tracks last-heartbeat-received time per
   running Firefox process. If Firefox is running and heartbeat is stale by
   5 minutes, quit Firefox. Re-check on relaunch.
6. **launchd packaging.** `LaunchAgent` plist with `KeepAlive: true` so the
   app relaunches if killed; `LSUIElement: true` so it's menu-bar-only, no
   Dock icon.
7. **Firefox enterprise policy lockdown.** `policies.json` /
   `ExtensionSettings` entry marking the extension `force_installed` so it
   can't be removed from `about:addons`.
8. **Docs pass.** README with plain-language setup instructions for Ria,
   and a short "how this works" doc for Stage/future-Stage.

Do not skip ahead to later phases before earlier ones are demonstrably
working — each phase should get its own commit(s) and, where feasible, a
manual test note in the PR/commit description describing exactly how it was
verified.

## 4. Git / GitHub sync requirement

This repo must be kept in sync with a **public** GitHub repo at all times:

- If no git repo exists yet in the working directory, run `git init`,
  create an initial commit, and create the GitHub repo via `gh repo create
  <name> --public --source=. --remote=origin --push` (ask the owner for the
  desired repo name and their GitHub account/org if not already configured;
  do not guess and do not make it private without being told to).
- If a remote already exists, just make sure every meaningful change is
  committed and pushed.
- Commit messages: short, imperative, describe *what* and *why* in one line,
  no fluff.
- Never commit secrets, API keys, or anything under a `.env` — add a
  `.gitignore` covering build artifacts, `.env`, `*.xcarchive`,
  `DerivedData/`, `node_modules/`, etc. as part of the very first commit.
- Since the repo is public: never commit real personal data (e.g. Ria's or
  Stage's actual blocklist contents, real channel IDs they personally block)
  — ship a `blocklist.example.json` with dummy entries instead, and
  gitignore the real one.

## 5. After every change

Per `CLAUDE.md`: build the whole project after every change, report build
status, and if the extension changed, give exact manual steps to reload/
reinstall it in Firefox (`about:debugging` → "This Firefox" → reload
temporary add-on, or full reinstall instructions if the manifest changed in
a way that requires it). Never assume the owner will infer this — spell it
out every time as if it's the first time.

## 6. First steps for the agent

1. Propose a repo name and directory layout (see `CLAUDE.md` for the
   required top-level structure) and confirm with the owner before creating
   anything, unless a layout is already obvious from an existing repo.
2. Set up `.gitignore`, initial commit, GitHub remote per section 4.
3. Start Phase 1 of the plan in section 3.
