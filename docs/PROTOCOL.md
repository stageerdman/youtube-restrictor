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
`SafariWebExtensionHandler` connects out to a small loopback-only TCP
listener the main app runs (`SafariLocalRelayServer.swift`, port in
`SafariRelayPort.swift`) — one connection per `beginRequest()`: the
extension sends `{"type": "heartbeat"}` and half-closes, the relay
server records the heartbeat straight into the same `HeartbeatMonitor`
Firefox/Chrome report to (it's running in-process, not IPC) and writes
back the current blocklist read live from `BlocklistStore`, then
closes.

This used to be an [App
Group](https://developer.apple.com/documentation/xcode/configuring-app-groups)
shared container (`group.com.stage-ria.ytrestrictor`) instead — a
`safari-blocklist.json` file `BlocklistStore` wrote on every edit, plus
a Darwin notification for the heartbeat. That was replaced entirely:
macOS's `kTCCServiceSystemPolicyAppData` check ("...would like to
access data from other apps") re-prompts for App Group container
access on **every single launch** of a process signed with a
development (non–Apple-Developer-Program) certificate, regardless of
how rarely the container is actually touched — confirmed by watching
`tccd` re-prompt twice in a row against the same unchanged, already-
running binary, no rebuild in between. A loopback TCP connection has no
such gate: sandboxed apps are allowed to make outgoing connections
silently via the `com.apple.security.network.client` entitlement,
granted at code-signing time with no runtime consent prompt at all, at
any frequency. Net effect: zero owner-facing prompts, ever, without
needing a paid Apple Developer Program membership. See git history
(commits around September 2026) for the full App Group version if
you're debugging something that assumes it still exists.

One build-tooling gotcha this surfaced: `xcodebuild`'s own
`RegisterWithLaunchServices` step registers the DerivedData copy of the
Safari Web Extension with `pluginkit` as a side effect of every build.
Left alone, that produces two registrations of the same extension
bundle ID, and Safari has been observed resolving to whichever it saw
first — silently running stale code no matter how many times
`scripts/package-menubar-app-xcode.sh` rebuilds
`menubar-app/build/YTRestrictor.app`. That script now explicitly
unregisters the DerivedData copy and registers the installed one via
`pluginkit -r`/`pluginkit -a` after every build — see the script for
why both calls are needed (macOS's own auto-discovery of the new copy
is asynchronous and isn't guaranteed to have run yet).

This is a deliberate adaptation of the same message shapes to a
transport Apple actually supports for Safari Web Extensions, not a
protocol version change — `heartbeat` and `blocklist-update` still mean
exactly what they mean above.
