# Native Messaging Protocol

Version: `0.1.0` — implemented by `native-host/`, `shared/messaging/`
(used by `extension-firefox/`, `extension-chrome/`, and
`extension-safari/`), and `menubar-app/`.

All messages are single-line JSON objects. The **message shapes** below
are shared by all three browsers, but the **transport** carrying them
differs for Safari — see "Safari's transport" at the end of this file
before assuming the stdio/socket description applies there too.

For Firefox and Chrome, messages are exchanged over Firefox's
[Native Messaging](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging)
stdio protocol (4-byte little-endian length prefix + UTF-8 JSON payload,
handled by the native messaging host — the extension and the menu bar app
never deal with framing directly, only with the JSON body below).

Every message has a `type` and a `version` field. Unknown `type` values
must be ignored (not error) by both sides, to allow forward compatibility.

## extension → native host → menu bar app

### `heartbeat`
Sent every 60s regardless of playback state, by
`shared/messaging/native-client.js`. `menubar-app/`'s
`HeartbeatMonitor` tracks the last one received; if Firefox is running
and none has arrived for 5 minutes, `EnforcementController` quits
Firefox (`FirefoxEnforcer`) — the menu bar app only needs to know
"extension is alive", not "video is playing".

```json
{ "type": "heartbeat", "version": "0.1.0", "timestamp": 1234567890000 }
```

**Chrome-specific caveat:** on Firefox, the background page (and its
native-messaging port) stays alive continuously. Chrome's MV3 service
worker gets killed after ~30s idle, taking the native-messaging port
down with it — `chrome.alarms` wakes it back up to send the next
heartbeat, but the port itself is only actually open for a brief window
around each heartbeat, not continuously. A `blocklist-update` pushed by
the menu bar app while Chrome's worker is asleep won't arrive until the
next heartbeat wakes it (up to ~60s later), unlike Firefox where it
arrives immediately. Both extensions still enforce every block locally
regardless of this, so this only affects how quickly a *new* blocklist
change propagates to an already-open Chrome tab.

### `match-detected`
Not implemented yet (no current consumer) — for visibility only, since
the extension always enforces the block locally regardless of whether
the app hears about it. Reserved shape:

```json
{
  "type": "match-detected",
  "version": "0.1.0",
  "timestamp": 1234567890000,
  "matchedRule": { "kind": "channel", "value": "Some Channel" },
  "context": { "url": "https://www.youtube.com/watch?v=...", "embedded": false }
}
```

## menu bar app → native host → extension

### `blocklist-update`
Pushed whenever the owner's blocklist changes in the menu bar app (after
any applicable confirmation/delay per `CLAUDE.md`'s asymmetric-friction
rule). Full replace, not a diff.

```json
{
  "type": "blocklist-update",
  "version": "0.1.0",
  "timestamp": 1234567890000,
  "blocklist": {
    "channels": ["Some Channel"],
    "videoIds": ["dQw4w9WgXcQ"],
    "keywords": ["clickbait term"]
  }
}
```

`channels` holds plain channel **display names** (e.g. `"Grian"`), not
channel IDs — matched case-insensitively. Native youtube.com pages read
the name straight off the page; embedded players (cross-origin iframes)
can't expose anything but a video ID, so the extension resolves the name
via YouTube's public oEmbed endpoint (see
`shared/messaging/oembed-resolver.js`) before matching.

## Versioning

Bump the minor version for additive/backward-compatible changes (new
optional fields, new message `type`), major for breaking changes to an
existing message shape. Both ends should log (not crash on) a
`version` they don't recognize.

## Safari's transport

Safari Web Extensions don't support spawning an external native-
messaging-host process the way Firefox and Chrome do — there's no
`native-host/host.js` equivalent on Safari, and no persistent
`browser.runtime.connectNative()` port. The only native-messaging API
Safari implements is one-shot `browser.runtime.sendNativeMessage()`,
which macOS routes directly to `SFSafariExtensionHandler.beginRequest()`
in `menubar-app/SafariExtension/SafariWebExtensionHandler.swift` — a
single request-in/response-out override, not a connection object either
side can push unsolicited messages on. `shared/messaging/native-client.js`
detects the missing `connectNative` at runtime and falls back to
`sendNativeMessage` automatically; no separate Safari-only copy of that
file exists.

Practical effect: **every `heartbeat` doubles as a poll for the current
blocklist on Safari.** The extension sends `heartbeat` as its
`sendNativeMessage` payload every 60s (same cadence as Firefox/Chrome);
`SafariWebExtensionHandler.beginRequest()` responds to that same call
with a `blocklist-update` message (or nothing new if nothing changed) —
there's no way for `menubar-app` to push a `blocklist-update` to Safari
the instant the owner edits the blocklist the way it does for
Firefox/Chrome over the socket. A blocklist change can take up to ~60s
to reach an already-open Safari tab. Firefox has no such gap; Chrome's
existing MV3 service-worker-sleep gap (see the heartbeat section above)
is a close analogue, not identical — Chrome's is incidental (only when
the worker happens to be asleep), Safari's is structural (every time).

Also structural: `SafariWebExtensionHandler` runs inside the Safari Web
Extension's own App Extension process (a `.appex`, sandboxed —
`com.apple.security.app-sandbox` is mandatory for Safari Web Extensions,
unlike `native-host/` and `menubar-app/`, which are deliberately
unsandboxed so they can use a plain Unix domain socket). A sandboxed
process can't open an arbitrary path like
`~/Library/Application Support/YTRestrictor/host.sock`. Instead,
`menubar-app`'s app target and its Safari Web Extension target share an
[App Group](https://developer.apple.com/documentation/xcode/configuring-app-groups)
container (`group.com.stage-ria.ytrestrictor` — see
`menubar-app/project.yml`), and relay through two small files there
instead of the socket:

- `safari-blocklist.json` — written by `BlocklistStore` (mirrors
  `blocklist.json` under Application Support) every time the blocklist
  changes; read by `beginRequest()` to build its `blocklist-update`
  response.
- `safari-heartbeat.json` — written by `beginRequest()` every time a
  `heartbeat` arrives; polled by `SafariHeartbeatWatcher` (menubar-app's
  main process, not sandboxed) roughly every 15s and fed into the same
  `HeartbeatMonitor` Firefox and Chrome already report to — so stale
  detection and quit-the-browser enforcement work identically across
  all three, just via a polled file instead of a live socket message on
  Safari's side.

This is a deliberate adaptation of the same message shapes to a
transport Apple actually supports for Safari Web Extensions, not a
protocol version change — `heartbeat` and `blocklist-update` still mean
exactly what they mean above.
