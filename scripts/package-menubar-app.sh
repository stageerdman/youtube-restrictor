#!/usr/bin/env bash
# Packages the built menubar-app executable into a minimal macOS .app
# bundle. No Xcode project exists (only Command Line Tools are
# available on this machine), so this hand-assembles the bundle
# structure from a `swift build -c release` output instead of using
# xcodebuild. Safe to re-run any time.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENUBAR_DIR="$REPO_ROOT/menubar-app"
BINARY="$MENUBAR_DIR/.build/release/YTRestrictor"
APP_BUNDLE="$MENUBAR_DIR/build/YTRestrictor.app"

if [ ! -x "$BINARY" ]; then
  echo "Release binary not found — building it first..."
  (cd "$MENUBAR_DIR" && swift build -c release)
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/YTRestrictor"
cp "$MENUBAR_DIR/Packaging/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "Packaged: $APP_BUNDLE"
