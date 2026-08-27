# Native Messaging Protocol

Version: `0.1.0` (draft — no native host implementation yet, this is the
target schema for Phase 3 of `INIT.md`)

All messages are single-line JSON objects exchanged over Firefox's
[Native Messaging](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging)
stdio protocol (4-byte little-endian length prefix + UTF-8 JSON payload,
handled by the native messaging host — the extension and the menu bar app
never deal with framing directly, only with the JSON body below).

Every message has a `type` and a `version` field. Unknown `type` values
must be ignored (not error) by both sides, to allow forward compatibility.

## extension → native host → menu bar app

### `heartbeat`
Sent periodically (every ~60s, see `extension/src/messaging/`) while at
least one tab has an active or recently-active YouTube/embedded player, or
on a fixed interval regardless of playback state (TBD in Phase 3 — the
menu bar app only needs to know "extension is alive", not "video is
playing").

```json
{ "type": "heartbeat", "version": "0.1.0", "timestamp": 1234567890000 }
```

### `match-detected`
Sent when the blocklist matcher blocks a player, for visibility only (the
extension enforces the block locally — this is informational, not a
permission request).

```json
{
  "type": "match-detected",
  "version": "0.1.0",
  "timestamp": 1234567890000,
  "matchedRule": { "kind": "channelId", "value": "UCxxxxxxxx" },
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
    "channelIds": ["UCxxxxxxxx"],
    "videoIds": ["dQw4w9WgXcQ"],
    "keywords": ["clickbait term"]
  }
}
```

## Versioning

Bump the minor version for additive/backward-compatible changes (new
optional fields, new message `type`), major for breaking changes to an
existing message shape. Both ends should log (not crash on) a
`version` they don't recognize.
