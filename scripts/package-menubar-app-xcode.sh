#!/usr/bin/env bash
# Builds menubar-app AND the Safari Web Extension via xcodebuild (real
# code signing required) and copies the result to
# menubar-app/build/YTRestrictor.app — the same path
# scripts/package-menubar-app.sh's plain `swift build` output uses, so
# `scripts/install-launch-agent.sh --xcode` can install it identically.
#
# Use this instead of package-menubar-app.sh only if you want Safari
# support. It requires:
#   - Full Xcode, not just Command Line Tools
#     (sudo xcode-select -s /Applications/Xcode.app/Contents/Developer)
#   - A Development Team selected for both the YTRestrictor and
#     YTRestrictorSafariExtension targets in Xcode's Signing &
#     Capabilities editor at least once (a free personal-team Apple ID
#     is enough — no paid Apple Developer Program membership needed for
#     local use). This is a one-time GUI step; see menubar-app/README.md's
#     "Safari Web Extension" section for exactly what to click.
#
# package-menubar-app.sh (plain `swift build`, no signing, no Safari
# extension) remains the default for Firefox/Chrome-only setups and
# needs none of the above.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENUBAR_DIR="$REPO_ROOT/menubar-app"
APP_BUNDLE="$MENUBAR_DIR/build/YTRestrictor.app"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "error: full Xcode is required (not just Command Line Tools)." >&2
  echo "Install Xcode from the App Store, then run:" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  echo "  sudo xcodebuild -license" >&2
  exit 1
fi

"$REPO_ROOT/scripts/generate-xcode-project.sh"

cd "$MENUBAR_DIR"
xcodebuild \
  -project YTRestrictor.xcodeproj \
  -scheme YTRestrictor \
  -configuration Release \
  -destination 'platform=macOS' \
  -allowProvisioningUpdates \
  build

BUILT_PRODUCTS_DIR="$(
  xcodebuild -project YTRestrictor.xcodeproj -scheme YTRestrictor -configuration Release \
    -destination 'platform=macOS' -showBuildSettings 2>/dev/null \
    | grep -m1 '^ *BUILT_PRODUCTS_DIR' | sed 's/^[^=]*= *//'
)"

rm -rf "$APP_BUNDLE"
mkdir -p "$MENUBAR_DIR/build"
cp -R "$BUILT_PRODUCTS_DIR/YTRestrictor.app" "$APP_BUNDLE"

echo "Packaged (code-signed, Safari extension embedded): $APP_BUNDLE"
