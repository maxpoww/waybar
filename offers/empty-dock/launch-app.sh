#!/usr/bin/env bash
# empty-dock/launch-app.sh
# Usage: launch-app.sh <exec> <name> [--print-icon <icon>]
# Increments launch_count in apps.json, then launches the app.
# With --print-icon: prints Waybar JSON for the icon slot and exits.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"

APP_EXEC="${1:?Usage: launch-app.sh <exec> <name> [--print-icon <icon>]}"
APP_NAME="${2:?}"
PRINT_ICON=0
ICON_NAME=""

if [[ "${3:-}" == "--print-icon" ]]; then
  PRINT_ICON=1
  ICON_NAME="${4:-}"
fi

APPS_FILE="${EMPTY_DOCK_APPS:-$SCRIPT_DIR/apps.json}"

# Increment launch_count for the matching exec entry
tmp=$(mktemp)
jq --arg exec "$APP_EXEC" '
  .apps |= map(if .exec == $exec then .launch_count += 1 else . end)
' "$APPS_FILE" > "$tmp" && mv "$tmp" "$APPS_FILE"

# Icon display mode: output Waybar JSON and exit (no actual launch)
if [[ "$PRINT_ICON" -eq 1 ]]; then
  echo "{\"text\":\"$ICON_NAME\",\"tooltip\":\"$APP_NAME\"}"
  exit 0
fi

# Launch app detached
log_info "Launching $APP_NAME ($APP_EXEC)"
if [[ "${EMPTY_DOCK_DRY_RUN:-0}" == "1" ]]; then
  log_info "DRY_RUN: exec $APP_EXEC"
  exit 0
fi

nohup "$APP_EXEC" &>/dev/null &
disown
