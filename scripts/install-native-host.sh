#!/usr/bin/env bash
# Registers native-host/host.js as a Firefox native messaging host by
# writing its manifest into Firefox's NativeMessagingHosts directory,
# with the absolute path to this checkout filled in. Re-run this any
# time the manifest template or the host's location changes.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_SCRIPT="$REPO_ROOT/native-host/host.js"
TEMPLATE="$REPO_ROOT/native-host/manifest/host-manifest.template.json"
TARGET_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
TARGET_FILE="$TARGET_DIR/com.stage_ria.ytrestrictor.json"

chmod +x "$HOST_SCRIPT"
mkdir -p "$TARGET_DIR"
sed "s#__HOST_PATH__#$HOST_SCRIPT#" "$TEMPLATE" > "$TARGET_FILE"

echo "Installed native messaging host manifest:"
echo "  $TARGET_FILE"
echo "Host script (must stay at this path, or re-run this script):"
echo "  $HOST_SCRIPT"
