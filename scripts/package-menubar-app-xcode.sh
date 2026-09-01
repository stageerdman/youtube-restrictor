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

# xcodebuild's own RegisterWithLaunchServices step (part of `build`
# above) registers the DerivedData copy's Safari Web Extension with
# pluginkit as a side effect, every single time. Left alone, that
# leaves two registrations of the same extension bundle ID — the stale
# DerivedData one and the one at $APP_BUNDLE this script just produced
# — and Safari has been observed resolving to whichever one it
# happens to pick, silently running old code no matter how many times
# this script rebuilds $APP_BUNDLE.
#
# A single pluginkit -r/-a pass isn't reliable here: lsregister's own
# registration (triggered by the `xcodebuild build` above) finishes
# asynchronously, sometimes *after* this script's own cleanup runs, and
# silently re-adds the DerivedData copy behind our back. Loop until
# `pluginkit -m` settles on exactly the one copy we want, rather than
# assuming one pass wins the race.
DERIVED_DATA_APPEX="$BUILT_PRODUCTS_DIR/YTRestrictor Safari Extension.appex"
INSTALLED_APPEX="$APP_BUNDLE/Contents/PlugIns/YTRestrictor Safari Extension.appex"
BUNDLE_ID="com.stage-ria.ytrestrictor-app.safari-extension"
for attempt in 1 2 3 4 5; do
  if [ -e "$DERIVED_DATA_APPEX" ]; then
    pluginkit -r "$DERIVED_DATA_APPEX" 2>/dev/null || true
  fi
  pluginkit -a "$INSTALLED_APPEX" 2>/dev/null || true
  sleep 1
  REGISTERED_PATHS="$(pluginkit -m -v -i "$BUNDLE_ID" 2>/dev/null | awk '{print $NF}')"
  if [ "$REGISTERED_PATHS" = "$INSTALLED_APPEX" ]; then
    break
  fi
  if [ "$attempt" = 5 ]; then
    echo "warning: could not get pluginkit to settle on $INSTALLED_APPEX alone" >&2
    echo "         (currently registered: $REGISTERED_PATHS) — Safari may still" >&2
    echo "         resolve a stale build. Re-run this script, or manually run:" >&2
    echo "         pluginkit -r \"$DERIVED_DATA_APPEX\"; pluginkit -a \"$INSTALLED_APPEX\"" >&2
  fi
done

echo "Packaged (code-signed, Safari extension embedded): $APP_BUNDLE"
