#!/usr/bin/env bash
# Registers native-host/host.js as a Firefox native messaging host by
# writing its manifest into Firefox's NativeMessagingHosts directory,
# with the absolute path to this checkout filled in. Re-run this any
# time the manifest template or the host's location changes, or if
# `node` moves (e.g. after a Homebrew upgrade).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_SCRIPT="$REPO_ROOT/native-host/host.js"
WRAPPER_TEMPLATE="$REPO_ROOT/native-host/manifest/run-host.template.sh"
WRAPPER_SCRIPT="$REPO_ROOT/native-host/manifest/run-host.sh"
MANIFEST_TEMPLATE="$REPO_ROOT/native-host/manifest/host-manifest.template.json"
TARGET_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
TARGET_FILE="$TARGET_DIR/com.stage_ria.ytrestrictor.json"

NODE_PATH="$(command -v node || true)"
if [ -z "$NODE_PATH" ]; then
  echo "error: could not find 'node' on PATH. Install Node.js first." >&2
  exit 1
fi

chmod +x "$HOST_SCRIPT"

# Firefox spawns native-messaging hosts with a minimal environment, so
# host.js's own `#!/usr/bin/env node` shebang can't be trusted to find
# node (e.g. Homebrew's /opt/homebrew/bin often isn't on a GUI app's
# PATH). This wrapper hardcodes the exact node path resolved just above.
sed \
  -e "s#__NODE_PATH__#$NODE_PATH#" \
  -e "s#__HOST_JS_PATH__#$HOST_SCRIPT#" \
  "$WRAPPER_TEMPLATE" > "$WRAPPER_SCRIPT"
chmod +x "$WRAPPER_SCRIPT"

mkdir -p "$TARGET_DIR"
sed "s#__HOST_PATH__#$WRAPPER_SCRIPT#" "$MANIFEST_TEMPLATE" > "$TARGET_FILE"

echo "Installed native messaging host manifest:"
echo "  $TARGET_FILE"
echo "Wrapper script (points at node: $NODE_PATH):"
echo "  $WRAPPER_SCRIPT"
echo "Host script (must stay at this path, or re-run this script):"
echo "  $HOST_SCRIPT"
