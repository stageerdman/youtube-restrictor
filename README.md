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

All 8 build phases are done (see `INIT.md` section 3 for the full
list). The extension detects and blocks YouTube playback, including
embeds; the menu bar app owns the blocklist with instant-add /
delayed-remove friction and a heartbeat that quits the browser if the
extension goes quiet; both are set up to survive restarts and can't be
casually removed — see "Setup" below for the real install, or
`docs/HOW-IT-WORKS.md` for the architecture behind all of it.

## Repo layout

- `extension/` — the Firefox WebExtension.
- `native-host/` — the native-messaging bridge (thin stdio↔socket pipe,
  no blocklist logic — see `native-host/README.md`).
- `menubar-app/` — the SwiftUI menu bar app that owns the blocklist and
  the asymmetric-friction rules — see `menubar-app/README.md`.
- `docs/PROTOCOL.md` — the JSON message format the extension and menu
  bar app use to talk to each other.
- `docs/HOW-IT-WORKS.md` — a short architecture overview, for whoever's
  touching the code next.

## Setup

This installs everything permanently: the browser extension (locked so
it can't be accidentally removed), the background app that holds your
blocklist, and the policy that keeps it all force-installed in
**Zen Browser** specifically (not regular Firefox — see
`docs/HOW-IT-WORKS.md` if you're curious why).

Run these three from a terminal, in the repo root, in order:

```
./scripts/install-native-host.sh
./scripts/install-launch-agent.sh
./scripts/install-policy.sh
```

What each one does:

1. **`install-native-host.sh`** registers the small background helper
   that lets the browser extension and the menu bar app talk to each
   other. Nothing visible happens — just some config files written to
   your Library folder.
2. **`install-launch-agent.sh`** builds the menu bar app and sets it up
   to start automatically every time you log in, and to restart itself
   if it's ever force-quit or crashes. You should see a small shield
   icon appear in your menu bar.
3. **`install-policy.sh`** locks the extension into Zen Browser so it
   can't be removed from `about:addons` with a click. **Quit Zen
   completely (Cmd+Q, not just closing the window) and reopen it**
   for this to take effect.

To check it worked: in Zen, open `about:addons` — "YouTube Restrictor"
should be listed with no "Remove" option next to it.

### Using it day to day

Click the shield icon in your menu bar to open the blocklist editor.
You can block by channel name, specific video, or keyword.

- **Adding** something to the blocklist takes effect immediately.
- **Removing** something asks you to retype it exactly, then puts it in
  a "Pending removals" list with a countdown (30 minutes by default)
  before it actually stops being blocked. You can cancel the removal
  any time before the countdown ends. This delay is the entire point of
  the tool — it's there so a moment of "I'll just unblock this one
  video real quick" doesn't undo the restriction. The delay itself
  (default 30 min) is adjustable in the app via a plain stepper — that
  control is *not* friction-gated, so if you want more friction, turn
  it up in a calm moment, not in the middle of wanting to unblock
  something.
- The app also keeps an eye on whether the browser extension is still
  responding. If Zen is open but the extension's gone quiet for 5
  minutes (e.g. it got disabled somehow), the app will quit Zen for
  you. Just reopen it.

### Uninstalling completely

You are always in full control of your own machine. To remove
everything permanently, run:

```
launchctl unload ~/Library/LaunchAgents/com.stage-ria.ytrestrictor-app.plist
rm ~/Library/LaunchAgents/com.stage-ria.ytrestrictor-app.plist
rm -rf menubar-app/build/YTRestrictor.app
rm /Applications/Zen.app/Contents/Resources/distribution/policies.json
```

Then remove the extension normally from `about:addons` in Zen. There's
no hidden step and nothing left behind that requires special tools —
this is a self-control tool, not something designed to resist you.

## For developers: trying the extension without installing anything

For quick iteration on extension code, without running any of the
install scripts above:

1. Open Firefox (or Zen) and go to `about:debugging#/runtime/this-firefox`.
2. Click **Load Temporary Add-on…** and select `extension/manifest.json`.
3. Open the browser console (`Ctrl+Shift+J` / `Cmd+Shift+J`) and visit a
   YouTube video, or any page with an embedded YouTube player — you
   should see `[YT Restrictor] detected player: ...` log lines.
4. To see blocking in action, visit
   [Never Gonna Give You Up](https://www.youtube.com/watch?v=dQw4w9WgXcQ)
   (or any video whose title contains "shorts") — it's on the hardcoded
   test blocklist, so it should pause immediately and get replaced with
   a "Blocked by YouTube Restrictor" placeholder.

This temporary install is unlocked (no policy lockdown) and resets when
Firefox/Zen restarts — it's for development only. For the real,
persistent setup, use the "Setup" section above. See `scripts/build.sh`
to build/lint/typecheck all three components at once.
