#!/usr/bin/env bash
# Copies shared/ (detection/matching/blocking logic + the runtime shim)
# into extension-firefox/src/, extension-chrome/src/, and
# extension-safari/src/. All three browsers load an extension from one
# self-contained directory and can't reference files outside it, so
# shared/ can't be loaded in place — it has to be physically copied into
# each extension's own tree first. For Safari specifically, this src/
# tree also gets embedded as the Safari Web Extension App Extension
# target's Resources by the Xcode project (see menubar-app/project.yml)
# — same copied files, just consumed by xcodebuild instead of loaded
# straight from disk by the browser.
#
# shared/ is the source of truth. Always edit there, never directly
# under extension-firefox/src/, extension-chrome/src/, or
# extension-safari/src/ — this script overwrites those on every run and
# does not warn about local edits.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for target in extension-firefox extension-chrome extension-safari; do
  rm -rf "$REPO_ROOT/$target/src"
  mkdir -p "$REPO_ROOT/$target/src"
  for entry in "$REPO_ROOT"/shared/*; do
    name="$(basename "$entry")"
    [ "$name" = "blocklist.example.json" ] && continue
    cp -R "$entry" "$REPO_ROOT/$target/src/$name"
  done
  echo "Synced shared/ -> $target/src/"
done
