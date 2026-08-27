#!/usr/bin/env bash
# Registers native-host/host.js as a Chrome native messaging host —
# same host.js as Firefox uses (see install-native-host.sh), just a
# second manifest, since Chrome and Firefox each keep their own
# NativeMessagingHosts registration directory and neither reads the
# other's.
#
# Chrome's "allowed_origins" needs the extension's ID. For an unpacked
# extension (no "key" field in manifest.json) Chrome derives that ID
# deterministically from the extension's absolute install path. This
# script computes it with that same algorithm, but that hasn't been
# verified against a real Chrome install in this environment — after
# loading extension-chrome/ as an unpacked extension, check the ID
# shown on chrome://extensions matches what this script printed. If it
# doesn't, re-run this script passing the real one:
#   ./scripts/install-native-host-chrome.sh <EXTENSION_ID>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_SCRIPT="$REPO_ROOT/native-host/host.js"
WRAPPER_TEMPLATE="$REPO_ROOT/native-host/manifest/run-host.template.sh"
WRAPPER_SCRIPT="$REPO_ROOT/native-host/manifest/run-host.sh"
MANIFEST_TEMPLATE="$REPO_ROOT/native-host/manifest/host-manifest-chrome.template.json"
TARGET_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
TARGET_FILE="$TARGET_DIR/com.stage_ria.ytrestrictor.json"
EXTENSION_DIR="$REPO_ROOT/extension-chrome"

NODE_PATH="$(command -v node || true)"
if [ -z "$NODE_PATH" ]; then
  echo "error: could not find 'node' on PATH. Install Node.js first." >&2
  exit 1
fi

if [ -n "${1:-}" ]; then
  EXTENSION_ID="$1"
  echo "Using extension ID passed on the command line: $EXTENSION_ID"
else
  EXTENSION_ID="$(node -e '
    const crypto = require("crypto");
    const hash = crypto.createHash("sha256").update(process.argv[1], "utf8").digest("hex").slice(0, 32);
    process.stdout.write([...hash].map(c => String.fromCharCode("a".charCodeAt(0) + parseInt(c, 16))).join(""));
  ' "$EXTENSION_DIR")"
  echo "Computed extension ID from path ($EXTENSION_DIR): $EXTENSION_ID"
  echo "Verify this matches the ID shown on chrome://extensions after loading"
  echo "extension-chrome/ unpacked — if not, re-run with the real ID as an argument."
fi

chmod +x "$HOST_SCRIPT"

# Same wrapper-script rationale as install-native-host.sh: Chrome also
# spawns native-messaging hosts with a minimal environment, so host.js's
# own shebang can't be trusted to find node.
sed \
  -e "s#__NODE_PATH__#$NODE_PATH#" \
  -e "s#__HOST_JS_PATH__#$HOST_SCRIPT#" \
  "$WRAPPER_TEMPLATE" > "$WRAPPER_SCRIPT"
chmod +x "$WRAPPER_SCRIPT"

mkdir -p "$TARGET_DIR"
sed \
  -e "s#__HOST_PATH__#$WRAPPER_SCRIPT#" \
  -e "s#__EXTENSION_ID__#$EXTENSION_ID#" \
  "$MANIFEST_TEMPLATE" > "$TARGET_FILE"

echo "Installed Chrome native messaging host manifest:"
echo "  $TARGET_FILE"
echo "Wrapper script (points at node: $NODE_PATH):"
echo "  $WRAPPER_SCRIPT"
