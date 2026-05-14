#!/usr/bin/env bash
# empty-dock/waybar-monitor.sh
# Daemon: shows/hides the dock Waybar when active workspace is empty.
# Source-only mode (--source-only) skips main() — used by unit tests.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"

WAYBAR_CMD="${WAYBAR_CMD:-waybar}"
WAYBAR_CONFIG="$SCRIPT_DIR/config.jsonc"
WAYBAR_STYLE="$SCRIPT_DIR/style.css"
DOCK_PID_FILE="${DOCK_PID_FILE:-/tmp/empty-dock-waybar.pid}"
POLL_INTERVAL="${EMPTY_DOCK_POLL:-2}"

# Returns 0 if workspace $1 has no windows, 1 otherwise.
workspace_is_empty() {
  local ws_id="$1"
  local windows
  windows=$(hyprctl workspaces -j \
    | jq --argjson id "$ws_id" '.[] | select(.id == $id) | .windows')
  [[ "${windows:-1}" -eq 0 ]]
}

# Returns the currently focused workspace id.
active_workspace_id() {
  hyprctl activeworkspace -j | jq '.id'
}

# Returns 0 if the dock Waybar process is alive.
dock_is_running() {
  [[ -f "$DOCK_PID_FILE" ]] && kill -0 "$(cat "$DOCK_PID_FILE")" 2>/dev/null
}

# Start the dock Waybar instance (idempotent).
dock_show() {
  dock_is_running && return 0
  if [[ "${EMPTY_DOCK_DRY_RUN:-0}" == "1" ]]; then
    log_info "DRY_RUN: start waybar -c $WAYBAR_CONFIG -s $WAYBAR_STYLE"
    return 0
  fi
  log_info "Showing dock"
  "$WAYBAR_CMD" -c "$WAYBAR_CONFIG" -s "$WAYBAR_STYLE" &
  echo $! > "$DOCK_PID_FILE"
}

# Stop the dock Waybar instance (idempotent).
dock_hide() {
  if [[ "${EMPTY_DOCK_DRY_RUN:-0}" == "1" ]]; then
    local pid
    pid=$(cat "$DOCK_PID_FILE" 2>/dev/null || echo "none")
    log_info "DRY_RUN: kill $pid"
    return 0
  fi
  if dock_is_running; then
    log_info "Hiding dock"
    kill "$(cat "$DOCK_PID_FILE")" && rm -f "$DOCK_PID_FILE"
  fi
}

# Main polling loop — not called when sourced for testing.
main() {
  log_info "empty-dock monitor started (poll=${POLL_INTERVAL}s)"
  local last_state=""
  while true; do
    local ws_id
    ws_id=$(active_workspace_id)
    if workspace_is_empty "$ws_id"; then
      [[ "$last_state" != "empty" ]] && dock_show
      last_state="empty"
    else
      [[ "$last_state" != "busy" ]] && dock_hide
      last_state="busy"
    fi
    sleep "$POLL_INTERVAL"
  done
}

# Only run main when executed directly, not when sourced for testing.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
