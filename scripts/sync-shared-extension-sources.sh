#!/usr/bin/env bash
# Copies shared/ (detection/matching/blocking logic + the runtime shim)
# into extension-firefox/src/ and extension-chrome/src/. Both browsers
# load an extension from one self-contained directory and can't
# reference files outside it, so shared/ can't be loaded in place —
# it has to be physically copied into each extension's own tree first.
#
# shared/ is the source of truth. Always edit there, never directly
# under extension-firefox/src/ or extension-chrome/src/ — this script
# overwrites those on every run and does not warn about local edits.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for target in extension-firefox extension-chrome; do
  rm -rf "$REPO_ROOT/$target/src"
  mkdir -p "$REPO_ROOT/$target/src"
  for entry in "$REPO_ROOT"/shared/*; do
    name="$(basename "$entry")"
    [ "$name" = "blocklist.example.json" ] && continue
    cp -R "$entry" "$REPO_ROOT/$target/src/$name"
  done
  echo "Synced shared/ -> $target/src/"
done
