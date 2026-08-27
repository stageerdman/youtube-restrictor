#!/usr/bin/env bash
# Builds everything: lints the extension, syntax-checks native-host, and
# builds + packages menubar-app. Per CLAUDE.md's mandatory build+report
# protocol — run this after any change and report what actually happened.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== extension: web-ext lint =="
(cd "$REPO_ROOT/extension" && npx --yes web-ext lint --source-dir .)

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
