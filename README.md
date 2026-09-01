# YouTube Restrictor

A personal self-control tool for blocking YouTube videos and channels you
choose to block — on youtube.com itself and on embedded players on other
sites. Built by and for its own owner, for one person's one browser on
one Mac. See `INIT.md` for the full project brief and `CLAUDE.md` for how
this repo is developed.

## How it works (eventually)

- A **browser extension** — Firefox/Zen, Chrome, and Safari all
  supported — watches for YouTube playback and checks it against a
  blocklist.
- A **macOS menu bar app** holds that blocklist, the same one either
  extension reads. You edit it there. Adding a restriction is instant;
  removing one takes a typed confirmation and a delay, on purpose —
  that delay is the whole point.
- Extensions talk to the app over the browser's native messaging
  system, on your machine only. Nothing is sent anywhere else.

You are always the ultimate authority over your own machine: deleting the
app, the browser policy file, and the background helper by hand removes
everything, permanently. This tool is meant to add friction to a habit
you want to change, not to fight you.

## Status

All 8 build phases from the original plan are done for **Firefox/Zen**
(see `INIT.md` section 3 for the full list) — the extension detects and
blocks YouTube playback including embeds, the menu bar app owns the
blocklist with instant-add / delayed-remove friction and a heartbeat
that quits the browser if the extension goes quiet, and both are set up
to survive restarts and can't be casually removed.

**Chrome support is newer and partial:** detection, blocking, and
native messaging to the same menu bar app all work (`extension-chrome/`,
Manifest V3). The force-install lockdown Firefox/Zen has (Phase 7) does
not exist yet for Chrome — it needs a different mechanism (a signed
`.crx` + a root-owned policy file) that hasn't been built. Until then,
Chrome only has a normal, removable "unpacked" install.

**Safari support is newer too, and structurally can't be locked down
the same way as Firefox/Zen — nor can any browser be, without MDM.**
Detection, blocking, and messaging to the same menu bar app all work
(`extension-safari/`, Manifest V3), but Safari Web Extensions don't
support the stdio native-messaging model Firefox/Chrome use at all —
`menubar-app/` itself had to become the Safari extension's container
app (an Xcode project now, alongside the still-working `Package.swift`)
and messages relay through a sandboxed App Extension talking to a
loopback-only TCP connection instead of the socket `native-host/` uses.
See
`docs/PROTOCOL.md`'s "Safari's transport" section and
`docs/HOW-IT-WORKS.md` for exactly why and what that changes. Like
Chrome, Safari only has a normal, removable install — enabled per
Safari's own Settings → Extensions toggle. See "Setup" below, or
`docs/HOW-IT-WORKS.md` for the architecture behind all of it.

## Repo layout

- `shared/` — the detection/matching/blocking/messaging logic used by
  *all three* browser extensions (copied into each one by
  `scripts/sync-shared-extension-sources.sh` — always edit here, never
  in the copies below).
- `extension-firefox/` — the Firefox/Zen WebExtension (Manifest V2).
- `extension-chrome/` — the Chrome extension (Manifest V3).
- `extension-safari/` — the Safari extension (Manifest V3); also
  embedded into `menubar-app/` as the Safari Web Extension's Resources.
- `native-host/` — the native-messaging bridge for Firefox/Chrome (thin
  stdio↔socket pipe, no blocklist logic — see `native-host/README.md`).
  Safari has no equivalent — see `docs/HOW-IT-WORKS.md`.
- `menubar-app/` — the SwiftUI menu bar app that owns the blocklist and
  the asymmetric-friction rules, the same one all three extensions talk
  to — see `menubar-app/README.md`. Also the Safari Web Extension's
  container app.
- `docs/PROTOCOL.md` — the JSON message format the extensions and menu
  bar app use to talk to each other.
- `docs/HOW-IT-WORKS.md` — a short architecture overview, for whoever's
  touching the code next.

## Setup

### Zen Browser (permanent, locked)

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

### Chrome (not locked down yet)

Chrome detection, blocking, and talking to the same menu bar app all
work — but there's no force-install lockdown for Chrome yet (see
"Status" above), so this is a normal, removable extension install for
now, closer to the Firefox "For developers" section below than to the
Zen setup above.

1. Register the native-messaging link (same background helper the Zen
   setup uses, just a second registration — Chrome and Firefox each
   keep their own):
   ```
   ./scripts/install-native-host-chrome.sh
   ```
   This computes the extension's ID from its install path and prints
   it. Keep that terminal output around for the next step.
2. Open `chrome://extensions`, turn on **Developer mode** (top right),
   click **Load unpacked**, and select the `extension-chrome/` folder
   from this repo.
3. Check the ID Chrome shows for it against what step 1 printed. If
   they don't match, re-run step 1 with the real one:
   `./scripts/install-native-host-chrome.sh <the-real-ID>`.
4. Make sure the menu bar app is running (see the Zen setup above if
   you haven't installed it yet — it's the same app, shared by both
   browsers). Open a YouTube tab in Chrome and check the console
   (`Cmd+Option+J`) for `[YT Restrictor]` log lines.

Because this isn't locked down, `chrome://extensions` can remove it
with one click at any time — same as any other unpacked extension. It
still gets blocklist updates from the same app, just with a Chrome-
specific quirk: because Chrome suspends the extension's background
process when idle, a blocklist change you make in the app can take up
to about a minute to reach an already-open Chrome tab, instead of
arriving instantly like it does in Zen (see `docs/PROTOCOL.md` for why).

### Safari (not locked down, and structurally can't be the same way)

Safari Web Extensions need more setup than Firefox/Chrome because
they have to ship inside a signed native app — that app is
`menubar-app/YTRestrictor`. Full instructions (including the one-time
Xcode signing step, which has to happen in Xcode's own GUI and can't be
scripted) are in `menubar-app/README.md`'s "Safari Web Extension"
section. Short version:

1. Install Xcode (not just Command Line Tools) and `brew install
   xcodegen`.
2. `cd menubar-app && ../scripts/generate-xcode-project.sh && open
   YTRestrictor.xcodeproj`.
3. In Xcode, pick your Apple ID as the Team for both the `YTRestrictor`
   and `YTRestrictorSafariExtension` targets (Signing & Capabilities) —
   a free account is enough, this never touches the App Store.
4. Build and run once from Xcode, then in Safari: Settings → Developer
   → **Allow Unsigned Extensions**, and Settings → Extensions → enable
   "YouTube Restrictor" and grant it `youtube.com` access.

Every blocklist change takes up to about a minute to reach an
already-open Safari tab — structurally, not incidentally, since Safari
extensions can only ever *poll* for updates rather than have them
pushed (see `docs/PROTOCOL.md`'s "Safari's transport" for exactly why).
Removing it is Settings → Extensions → uncheck the box, or delete
`YTRestrictor.app` entirely — same as removing the menu bar app itself,
since there's nothing Safari-specific left behind once that's gone.

### Uninstalling completely

You are always in full control of your own machine. To remove
everything permanently, run:

```
launchctl unload ~/Library/LaunchAgents/com.stage-ria.ytrestrictor-app.plist
rm ~/Library/LaunchAgents/com.stage-ria.ytrestrictor-app.plist
rm -rf menubar-app/build/YTRestrictor.app
rm /Applications/Zen.app/Contents/Resources/distribution/policies.json
rm "$HOME/Library/Application Support/Mozilla/NativeMessagingHosts/com.stage_ria.ytrestrictor.json"
rm "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.stage_ria.ytrestrictor.json"
```

Then remove the extension normally from `about:addons` in Zen,
`chrome://extensions` in Chrome, and/or Safari → Settings →
Extensions. There's no hidden step and nothing left behind that
requires special tools — this is a self-control tool, not something
designed to resist you.

## For developers: trying the Firefox/Zen extension without installing anything

For quick iteration on extension code, without running any of the
install scripts above:

1. Open Firefox (or Zen) and go to `about:debugging#/runtime/this-firefox`.
2. Click **Load Temporary Add-on…** and select
   `extension-firefox/manifest.json`.
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
persistent setup, use the "Setup" section above. (For Chrome, there's
no separate dev-only flow — "Load unpacked" in the Chrome setup section
above already is the lightweight iteration path, since Chrome has no
lockdown yet to route around. For Safari, there's no lightweight flow
either — "Allow Unsigned Extensions" + Settings → Extensions in the
Safari setup section above already is the equivalent of an unpacked/
temporary install, since Safari requires the signed container app
either way.) See `scripts/build.sh` to build/lint/typecheck everything
at once — it also re-syncs `shared/` into all three extensions first.
