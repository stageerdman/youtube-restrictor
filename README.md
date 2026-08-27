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

Currently: **Phase 1 — extension playback detection.** The extension
detects YouTube videos playing on youtube.com/youtu.be and in embedded
players on other sites, and logs what it finds to the browser console.
It does not block anything yet, and there is no menu bar app or
blocklist enforcement yet — see `INIT.md` section 3 for the full build
order.

## Repo layout

- `extension/` — the Firefox WebExtension.
- `native-host/` — the small native-messaging bridge (not built yet).
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
