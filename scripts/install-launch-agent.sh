#!/usr/bin/env bash
# Packages menubar-app and registers it as a LaunchAgent: RunAtLoad so
# it starts at login, KeepAlive so macOS relaunches it if it's ever
# killed (crash, force-quit, or its own Quit button). Re-run this any
# time the plist template changes or the repo moves.
#
# To fully and permanently remove it (the owner is always the ultimate
# authority — see CLAUDE.md):
#   launchctl unload ~/Library/LaunchAgents/com.stage-ria.ytrestrictor-app.plist
#   rm ~/Library/LaunchAgents/com.stage-ria.ytrestrictor-app.plist
#   rm -rf <this repo>/menubar-app/build/YTRestrictor.app
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$REPO_ROOT/menubar-app/build/YTRestrictor.app"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/YTRestrictor"
PLIST_TEMPLATE="$REPO_ROOT/menubar-app/Packaging/launch-agent.template.plist"
LABEL="com.stage-ria.ytrestrictor-app"
TARGET_DIR="$HOME/Library/LaunchAgents"
TARGET_FILE="$TARGET_DIR/$LABEL.plist"
LOG_DIR="$HOME/Library/Application Support/YTRestrictor/logs"

"$REPO_ROOT/scripts/package-menubar-app.sh"

mkdir -p "$TARGET_DIR" "$LOG_DIR"
sed \
  -e "s#__EXECUTABLE_PATH__#$EXECUTABLE#" \
  -e "s#__STDOUT_PATH__#$LOG_DIR/stdout.log#" \
  -e "s#__STDERR_PATH__#$LOG_DIR/stderr.log#" \
  "$PLIST_TEMPLATE" > "$TARGET_FILE"

# Reload cleanly if a previous version is already loaded.
launchctl unload "$TARGET_FILE" >/dev/null 2>&1 || true
launchctl load -w "$TARGET_FILE"

echo "Installed and loaded LaunchAgent:"
echo "  $TARGET_FILE"
echo "App bundle:"
echo "  $APP_BUNDLE"
echo "Logs:"
echo "  $LOG_DIR"
echo
echo "It will now start automatically at login and relaunch if killed."
