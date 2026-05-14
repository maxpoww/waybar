#!/usr/bin/env bash
# empty-dock/add-app.sh
# Opens rofi/wofi to pick a .desktop entry and adds it to apps.json.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"

APPS_FILE="${EMPTY_DOCK_APPS:-$SCRIPT_DIR/apps.json}"

# Collect installed app names from .desktop files
desktop_dirs=(
  "/usr/share/applications"
  "$HOME/.local/share/applications"
  "/run/current-system/sw/share/applications"
)

desktop_list=""
for dir in "${desktop_dirs[@]}"; do
  [[ -d "$dir" ]] || continue
  while IFS= read -r -d '' file; do
    name=$(grep -m1 '^Name=' "$file" 2>/dev/null | sed 's/^Name=//')
    [[ -n "$name" ]] && desktop_list+="$name"$'\n'
  done < <(find "$dir" -maxdepth 1 -name '*.desktop' -print0 2>/dev/null)
done

desktop_list=$(echo "$desktop_list" | sort -u)
[[ -z "$desktop_list" ]] && log_error "No .desktop files found" && exit 1

# Present picker
chosen=$(echo "$desktop_list" \
  | rofi -dmenu -p "Add app to dock" 2>/dev/null) \
  || chosen=$(echo "$desktop_list" \
  | wofi --dmenu --prompt "Add app to dock" 2>/dev/null) \
  || chosen=""

[[ -z "$chosen" ]] && exit 0

# Find the matching .desktop file
desktop_file=""
for dir in "${desktop_dirs[@]}"; do
  [[ -d "$dir" ]] || continue
  found=$(grep -rl "^Name=$chosen$" "$dir" 2>/dev/null | head -1)
  if [[ -n "$found" ]]; then
    desktop_file="$found"
    break
  fi
done

if [[ -z "$desktop_file" ]]; then
  log_error "Desktop file not found for: $chosen"
  exit 1
fi

exec_line=$(grep -m1 '^Exec=' "$desktop_file" | sed 's/^Exec=//' | sed 's/ %[^ ]*//')
icon_line=$(grep -m1 '^Icon=' "$desktop_file" | sed 's/^Icon=//')

# Generate next id (max existing id + 1, or 0 if empty)
next_id=$(jq '(.apps | map(.id) | max // -1) + 1' "$APPS_FILE")

tmp=$(mktemp)
jq --argjson id "$next_id" \
   --arg name "$chosen" \
   --arg exec "$exec_line" \
   --arg icon "$icon_line" '
  .apps += [{
    "id": $id,
    "name": $name,
    "exec": $exec,
    "icon": $icon,
    "launch_count": 0,
    "pinned": false
  }]
' "$APPS_FILE" > "$tmp" && mv "$tmp" "$APPS_FILE"

log_info "Added app: $chosen ($exec_line)"
bash "$SCRIPT_DIR/update-launchers.sh"
pkill -USR2 waybar 2>/dev/null || true
