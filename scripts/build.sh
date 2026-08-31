#!/usr/bin/env bash
# Builds everything: syncs shared/ into both extensions, lints the
# Firefox extension, syntax-checks the Chrome extension and
# native-host, and builds + packages menubar-app. Per CLAUDE.md's
# mandatory build+report protocol — run this after any change and
# report what actually happened.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== extensions: sync shared/ sources =="
"$REPO_ROOT/scripts/sync-shared-extension-sources.sh"

echo
echo "== extension-firefox: web-ext lint =="
(cd "$REPO_ROOT/extension-firefox" && npx --yes web-ext lint --source-dir .)

echo
echo "== extension-chrome: manifest + syntax check =="
node -e "JSON.parse(require('fs').readFileSync('$REPO_ROOT/extension-chrome/manifest.json'))" \
  && echo "OK: extension-chrome/manifest.json is valid JSON"
node --check "$REPO_ROOT/extension-chrome/service-worker.js" && echo "OK: extension-chrome/service-worker.js"
find "$REPO_ROOT/extension-chrome/src" -name '*.js' -print0 | while IFS= read -r -d '' f; do
  node --check "$f" && echo "OK: $f"
done

echo
echo "== extension-safari: manifest + syntax check =="
node -e "JSON.parse(require('fs').readFileSync('$REPO_ROOT/extension-safari/manifest.json'))" \
  && echo "OK: extension-safari/manifest.json is valid JSON"
node --check "$REPO_ROOT/extension-safari/service-worker.js" && echo "OK: extension-safari/service-worker.js"
find "$REPO_ROOT/extension-safari/src" -name '*.js' -print0 | while IFS= read -r -d '' f; do
  node --check "$f" && echo "OK: $f"
done

echo
echo "== native-host: syntax check =="
for f in "$REPO_ROOT"/native-host/host.js "$REPO_ROOT"/native-host/src/*.js "$REPO_ROOT"/native-host/test/*.js; do
  node --check "$f" && echo "OK: $f"
done

echo
echo "== menubar-app: swift build (release) =="
(cd "$REPO_ROOT/menubar-app" && swift build -c release)

echo
echo "== menubar-app: packaging .app bundle (Firefox/Chrome only, no Safari) =="
"$REPO_ROOT/scripts/package-menubar-app.sh"

if command -v xcodebuild >/dev/null 2>&1 && xcodebuild -version >/dev/null 2>&1; then
  echo
  echo "== menubar-app + Safari extension: xcodebuild (compile check, unsigned) =="
  "$REPO_ROOT/scripts/generate-xcode-project.sh"
  (cd "$REPO_ROOT/menubar-app" && xcodebuild \
    -project YTRestrictor.xcodeproj -scheme YTRestrictor -configuration Debug \
    -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
    build)
  echo "(unsigned — this only verifies both targets compile and link; it does"
  echo " not produce a runnable, code-signed .app. See menubar-app/README.md's"
  echo " \"Safari Web Extension\" section for the real, signed build.)"
else
  echo
  echo "== menubar-app + Safari extension: SKIPPED =="
  echo "Full Xcode isn't active (xcode-select is pointing at Command Line"
  echo "Tools, or Xcode isn't installed) — the Safari extension target"
  echo "can't be built without it. Firefox/Chrome are unaffected."
fi

echo
echo "Build complete."
