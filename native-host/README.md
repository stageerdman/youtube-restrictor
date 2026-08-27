# native-host

A thin, dumb pipe between a browser extension (Firefox/Zen or Chrome)
and the macOS menu bar app. It has no blocklist logic — see
`CLAUDE.md`. The same `host.js` serves both browsers; only the
registration manifest differs, since Firefox and Chrome each keep their
own separate `NativeMessagingHosts` directory and neither reads the
other's.

- `host.js` — entrypoint. The browser spawns this per native-messaging
  session and talks to it over stdin/stdout.
- `src/stdio-framing.js` — reads/writes the native-messaging wire format
  (4-byte length prefix + UTF-8 JSON) common to both Firefox and Chrome.
- `src/socket-bridge.js` — forwards every message to/from a local Unix
  domain socket, where the menu bar app listens. Retries the connection
  if the app isn't running.
- `src/socket-path.js` — the one place that defines the socket path
  (`~/Library/Application Support/YTRestrictor/host.sock`).
- `manifest/host-manifest.template.json` + `scripts/install-native-host.sh`
  — registers this host with Firefox.
- `manifest/host-manifest-chrome.template.json` +
  `scripts/install-native-host-chrome.sh` — registers this host with
  Chrome (needs the extension's ID, computed from its install path by
  the script — see the script's header comment for the caveat on that).

## Testing this in isolation (menu bar app doesn't exist yet)

1. `node native-host/host.js` isn't meant to be run by hand — Firefox
   spawns it — but you can exercise the whole pipe manually:
2. In one terminal, start the stand-in for the menu bar app:
   ```
   node native-host/test/fake-app-server.js
   ```
3. Install the native messaging host manifest (only needed once, or
   again if the manifest/path changes):
   ```
   ./scripts/install-native-host.sh
   ```
4. Load the extension in Firefox (see repo root README) and open the
   Browser Console. Within ~60s you should see a heartbeat go out, and
   the `fake-app-server` terminal will log it. ~3s after the host
   connects, `fake-app-server` pushes a test blocklist update; the
   extension should log receiving it, and a tab open to
   `https://www.youtube.com/watch?v=jNQXAC9IVRw` ("Me at the zoo")
   should get blocked — proving a real update travels
   app → socket → host → stdout → extension → storage → block pipeline
   end-to-end, without the real menu bar app existing yet.
