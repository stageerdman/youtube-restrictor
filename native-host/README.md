# native-host

A thin, dumb pipe between the Firefox extension and the macOS menu bar
app (Phase 4, not built yet). It has no blocklist logic — see
`CLAUDE.md`.

- `host.js` — entrypoint. Firefox spawns this per native-messaging
  session and talks to it over stdin/stdout.
- `src/stdio-framing.js` — reads/writes Firefox's native-messaging wire
  format (4-byte length prefix + UTF-8 JSON).
- `src/socket-bridge.js` — forwards every message to/from a local Unix
  domain socket, where the menu bar app will listen once it exists.
  Retries the connection if the app isn't running.
- `src/socket-path.js` — the one place that defines the socket path
  (`~/Library/Application Support/YTRestrictor/host.sock`).
- `manifest/host-manifest.template.json` + `scripts/install-native-host.sh`
  — registers this host with Firefox.

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
