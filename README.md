# YouTube Restrictor

A personal self-control tool for blocking YouTube videos and channels you
choose to block — on youtube.com itself and on embedded players on other
sites. Built by and for its own owner, for one person's one browser on
one Mac. See `INIT.md` for the full project brief and `CLAUDE.md` for how
this repo is developed.

## How it works (eventually)

- A **Firefox extension** watches for YouTube playback and checks it
  against a blocklist.
- A **macOS menu bar app** holds that blocklist. You edit it there.
  Adding a restriction is instant; removing one takes a typed
  confirmation and a delay, on purpose — that delay is the whole point.
- The two talk to each other over Firefox's native messaging system, on
  your machine only. Nothing is sent anywhere else.

You are always the ultimate authority over your own machine: deleting the
app, the browser policy file, and the background helper by hand removes
everything, permanently. This tool is meant to add friction to a habit
you want to change, not to fight you.

## Status

Currently: **Phase 7 — Firefox enterprise-policy lockdown.** All three
components exist and talk to each other end-to-end: the extension
detects and blocks YouTube playback, including embeds (Phases 1–2),
`native-host/` is the dumb stdio↔socket pipe (Phase 3), and
`menubar-app/` (Phase 4) is the real SwiftUI app that owns the blocklist
— add/remove UI, JSON persistence, pushing updates to the extension the
moment they change. Removing an entry requires retyping it to confirm
and then waits out an owner-configurable delay (default 30 min,
cancellable any time before it applies) before it actually stops being
enforced — adding one is always instant. The app also tracks whether
the extension is still checking in (every 60s) and, if Firefox is
running and that goes stale for 5 minutes, quits it (Phase 5), and it's
packaged as a real `.app` running under `launchd` with `KeepAlive` so it
survives being killed (Phase 6).

New in Phase 7: the extension is force-installed via an enterprise
`policies.json` — `about:addons` no longer offers a Remove button for
it. This targets **Zen Browser** (the owner's actual daily browser, a
Firefox fork), not release Firefox: force-installing an unsigned
extension requires disabling signature enforcement via policy, which
release Firefox hard-blocks regardless of policy (a Mozilla security
guardrail). Zen already ships with
`xpinstall.signatures.required=false` by default, so this works without
needing Firefox Developer Edition or Mozilla's AMO signing process at
all. See `scripts/install-policy.sh` for the exact mechanism. Not built
yet: the docs pass (Phase 8) — see `INIT.md` section 3 for the full
build order.

## Repo layout

- `extension/` — the Firefox WebExtension.
- `native-host/` — the native-messaging bridge (thin stdio↔socket pipe,
  no blocklist logic — see `native-host/README.md`).
- `menubar-app/` — the SwiftUI menu bar app that owns the blocklist and
  the asymmetric-friction rules — see `menubar-app/README.md`.
- `docs/PROTOCOL.md` — the JSON message format the extension and menu
  bar app use to talk to each other.

## Trying the extension right now

See the "Trying it" steps in the latest commit/PR description, or:

1. Open Firefox and go to `about:debugging#/runtime/this-firefox`.
2. Click **Load Temporary Add-on…** and select `extension/manifest.json`.
3. Open the browser console (`Ctrl+Shift+J` / `Cmd+Shift+J`) and visit a
   YouTube video, or any page with an embedded YouTube player — you
   should see `[YT Restrictor] detected player: ...` log lines.
4. To see blocking in action, visit
   [Never Gonna Give You Up](https://www.youtube.com/watch?v=dQw4w9WgXcQ)
   (or any video whose title contains "shorts") — it's on the hardcoded
   test blocklist, so it should pause immediately and get replaced with
   a "Blocked by YouTube Restrictor" placeholder.
