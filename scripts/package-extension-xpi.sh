#!/usr/bin/env bash
# Packages extension/ into a stable-named .xpi at extension/build/, so
# the policy's install_url doesn't have to change on every version bump
# (web-ext build's own output filename bakes in the version number).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXTENSION_DIR="$REPO_ROOT/extension"
BUILD_DIR="$EXTENSION_DIR/build"
XPI_PATH="$BUILD_DIR/youtube-restrictor.xpi"

rm -rf "$EXTENSION_DIR/web-ext-artifacts"
(cd "$EXTENSION_DIR" && npx --yes web-ext build --overwrite-dest)

ZIP_PATH="$(find "$EXTENSION_DIR/web-ext-artifacts" -name '*.zip' | head -1)"
mkdir -p "$BUILD_DIR"
cp "$ZIP_PATH" "$XPI_PATH"

echo "Packaged: $XPI_PATH"
