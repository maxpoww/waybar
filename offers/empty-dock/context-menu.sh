#!/usr/bin/env bash
# empty-dock/context-menu.sh
# Usage: context-menu.sh <app_id>
# Right-click handler: pin/unpin or remove an app from the dock.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"

APP_ID="${1:?Usage: context-menu.sh <app_id>}"
APPS_FILE="${EMPTY_DOCK_APPS:-$SCRIPT_DIR/apps.json}"

APP_NAME=$(jq -r --argjson id "$APP_ID" '.apps[] | select(.id == $id) | .name' "$APPS_FILE")
IS_PINNED=$(jq -r --argjson id "$APP_ID" '.apps[] | select(.id == $id) | .pinned' "$APPS_FILE")

PIN_LABEL="Pin"
[[ "$IS_PINNED" == "true" ]] && PIN_LABEL="Unpin"

# Present menu — try rofi first, fall back to wofi
choice=$(printf '%s\nRemove' "$PIN_LABEL" \
  | rofi -dmenu -p "$APP_NAME" 2>/dev/null) \
  || choice=$(printf '%s\nRemove' "$PIN_LABEL" \
  | wofi --dmenu --prompt "$APP_NAME" 2>/dev/null) \
  || choice=""

[[ -z "$choice" ]] && exit 0

tmp=$(mktemp)
case "$choice" in
  Pin)
    jq --argjson id "$APP_ID" \
      '.apps |= map(if .id == $id then .pinned = true else . end)' \
      "$APPS_FILE" > "$tmp" && mv "$tmp" "$APPS_FILE"
    log_info "Pinned app id=$APP_ID ($APP_NAME)"
    ;;
  Unpin)
    jq --argjson id "$APP_ID" \
      '.apps |= map(if .id == $id then .pinned = false else . end)' \
      "$APPS_FILE" > "$tmp" && mv "$tmp" "$APPS_FILE"
    log_info "Unpinned app id=$APP_ID ($APP_NAME)"
    ;;
  Remove)
    jq --argjson id "$APP_ID" \
      '.apps |= map(select(.id != $id))' \
      "$APPS_FILE" > "$tmp" && mv "$tmp" "$APPS_FILE"
    log_info "Removed app id=$APP_ID ($APP_NAME)"
    ;;
  *)
    rm -f "$tmp"
    exit 0
    ;;
esac

bash "$SCRIPT_DIR/update-launchers.sh"
pkill -USR2 waybar 2>/dev/null || true
