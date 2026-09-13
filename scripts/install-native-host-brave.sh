#!/usr/bin/env bash
# Registers native-host/host.js as a Brave native messaging host — same
# host.js as Chrome/Firefox use (see install-native-host-chrome.sh),
# just a third manifest, since Brave keeps its own NativeMessagingHosts
# registration directory and doesn't read Chrome's. Brave loads
# extension-chrome/ unpacked directly (no extension-brave/ — Brave is
# Chromium under the hood and needs no code changes), so the extension
# ID derivation below is identical to Chrome's script.
#
# Brave's "allowed_origins" needs the extension's ID. For an unpacked
# extension (no "key" field in manifest.json) Brave derives that ID
# with the same algorithm Chrome uses, deterministically from the
# extension's absolute install path. This script computes it with that
# same algorithm, but that hasn't been verified against a real Brave
# install in this environment — after loading extension-chrome/ as an
# unpacked extension in brave://extensions, check the ID shown there
# matches what this script printed. If it doesn't, re-run this script
# passing the real one:
#   ./scripts/install-native-host-brave.sh <EXTENSION_ID>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_SCRIPT="$REPO_ROOT/native-host/host.js"
WRAPPER_TEMPLATE="$REPO_ROOT/native-host/manifest/run-host.template.sh"
WRAPPER_SCRIPT="$REPO_ROOT/native-host/manifest/run-host.sh"
MANIFEST_TEMPLATE="$REPO_ROOT/native-host/manifest/host-manifest-chrome.template.json"
TARGET_DIR="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
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
  echo "Verify this matches the ID shown on brave://extensions after loading"
  echo "extension-chrome/ unpacked — if not, re-run with the real ID as an argument."
fi

chmod +x "$HOST_SCRIPT"

# Same wrapper-script rationale as install-native-host-chrome.sh: Brave
# also spawns native-messaging hosts with a minimal environment, so
# host.js's own shebang can't be trusted to find node. This wrapper is
# shared with the Chrome registration (both point at the same node/
# host.js pair) — regenerating it here is a no-op if Chrome's install
# script already wrote the same thing.
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

echo "Installed Brave native messaging host manifest:"
echo "  $TARGET_FILE"
echo "Wrapper script (points at node: $NODE_PATH):"
echo "  $WRAPPER_SCRIPT"
