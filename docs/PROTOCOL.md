# Native Messaging Protocol

Version: `0.1.0` — implemented by `native-host/`, `shared/messaging/`
(used by both `extension-firefox/` and `extension-chrome/`), and
`menubar-app/`.

All messages are single-line JSON objects exchanged over Firefox's
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
