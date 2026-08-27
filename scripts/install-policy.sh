#!/usr/bin/env bash
# Locks the extension in place via an enterprise policies.json:
# force_installed, so it can't be removed from about:addons without
# editing this file (or the app bundle) directly by hand — see
# CLAUDE.md's owner-is-the-ultimate-authority principle.
#
# Targets Zen Browser (a Firefox fork — the owner's actual daily
# browser), not release Firefox: force-installing an unsigned extension
# needs signature enforcement disabled, which release Firefox hard-blocks
# regardless of policy. Zen already ships with
# xpinstall.signatures.required=false by default (confirmed in its
# bundled greprefs.js), so this works without needing Firefox Developer
# Edition or Mozilla's AMO signing process at all.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="/Applications/Zen.app"
EXTENSION_ID="youtube-restrictor@stage-ria.local"
POLICY_TEMPLATE="$REPO_ROOT/extension-firefox/policies.template.json"
DISTRIBUTION_DIR="$APP_BUNDLE/Contents/Resources/distribution"
TARGET_FILE="$DISTRIBUTION_DIR/policies.json"

if [ ! -d "$APP_BUNDLE" ]; then
  echo "error: '$APP_BUNDLE' not found." >&2
  exit 1
fi

"$REPO_ROOT/scripts/package-extension-xpi.sh"
XPI_PATH="$REPO_ROOT/extension/build/youtube-restrictor.xpi"

mkdir -p "$DISTRIBUTION_DIR"
sed \
  -e "s#__EXTENSION_ID__#$EXTENSION_ID#" \
  -e "s#__XPI_FILE_URL__#file://$XPI_PATH#" \
  "$POLICY_TEMPLATE" > "$TARGET_FILE"

echo "Installed policy lockdown:"
echo "  $TARGET_FILE"
echo
echo "NOTE: Zen updates likely replace the whole .app bundle, which wipes"
echo "this file out. Re-run this script after any Zen update."
echo
echo "Quit Zen COMPLETELY (Cmd+Q, not just closing windows) and relaunch"
echo "it for the policy to take effect. Check about:policies to confirm"
echo "it was read, and about:addons — the extension should be listed"
echo "with no Remove button."
