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
echo "== native-host: syntax check =="
for f in "$REPO_ROOT"/native-host/host.js "$REPO_ROOT"/native-host/src/*.js "$REPO_ROOT"/native-host/test/*.js; do
  node --check "$f" && echo "OK: $f"
done

echo
echo "== menubar-app: swift build (release) =="
(cd "$REPO_ROOT/menubar-app" && swift build -c release)

echo
echo "== menubar-app: packaging .app bundle =="
"$REPO_ROOT/scripts/package-menubar-app.sh"

echo
echo "Build complete."
