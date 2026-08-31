#!/usr/bin/env bash
# Regenerates menubar-app/YTRestrictor.xcodeproj from menubar-app/project.yml
# via xcodegen. Needed for the Safari Web Extension target — Swift Package
# Manager (menubar-app/Package.swift, still used for `swift build`/`swift
# run` against the non-Safari code) can't build App Extension bundle
# products. Safe to re-run any time; the .xcodeproj is gitignored and
# never hand-edited — project.yml is the source of truth.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen not found on PATH. Install it with: brew install xcodegen" >&2
  exit 1
fi

# extension-safari/src/ (embedded as the extension target's Resources)
# comes from shared/ — make sure it's current before generating.
"$REPO_ROOT/scripts/sync-shared-extension-sources.sh"

(cd "$REPO_ROOT/menubar-app" && xcodegen generate)

echo "Generated menubar-app/YTRestrictor.xcodeproj from menubar-app/project.yml"
