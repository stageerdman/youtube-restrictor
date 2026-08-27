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

Currently: **Phase 3 — native messaging host.** The extension detects
YouTube videos, matches them against a blocklist, and blocks matches
(Phases 1–2). It now also sends a heartbeat to a native messaging host
(`native-host/`) every 60s and can receive a real blocklist over that
channel, which takes over from the hardcoded test blocklist the moment
one arrives. The menu bar app that owns and pushes the real blocklist
doesn't exist yet (Phase 4) — until it does, `native-host/` just forwards
to a Unix socket nothing is listening on, so the extension quietly keeps
using its hardcoded test blocklist. See `native-host/README.md` for how
to exercise the whole pipe manually with a stand-in test server, and
`INIT.md` section 3 for the full build order.

## Repo layout

- `extension/` — the Firefox WebExtension.
- `native-host/` — the native-messaging bridge (thin stdio↔socket pipe,
  no blocklist logic — see `native-host/README.md`).
- `menubar-app/` — the SwiftUI menu bar app (not built yet).
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
