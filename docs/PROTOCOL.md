# Native Messaging Protocol

Version: `0.1.0` — implemented by `native-host/`, `extension/src/messaging/`,
and `menubar-app/`.

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
`extension/src/messaging/native-client.js` — the menu bar app only needs
to know "extension is alive" (for Phase 5's enforcement check), not
"video is playing".

```json
{ "type": "heartbeat", "version": "0.1.0", "timestamp": 1234567890000 }
```

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
`extension/src/messaging/oembed-resolver.js`) before matching.

## Versioning

Bump the minor version for additive/backward-compatible changes (new
optional fields, new message `type`), major for breaking changes to an
existing message shape. Both ends should log (not crash on) a
`version` they don't recognize.
