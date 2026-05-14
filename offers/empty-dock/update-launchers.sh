#!/usr/bin/env bash
# empty-dock/update-launchers.sh
# Regenerates config.jsonc from apps.json using jq only (no python).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"

APPS_FILE="${EMPTY_DOCK_APPS:-$SCRIPT_DIR/apps.json}"
CONFIG_OUT="${EMPTY_DOCK_CONFIG_OUT:-$SCRIPT_DIR/config.jsonc}"
LAUNCH_SCRIPT="$SCRIPT_DIR/launch-app.sh"
CTX_SCRIPT="$SCRIPT_DIR/context-menu.sh"
ADD_SCRIPT="$SCRIPT_DIR/add-app.sh"

# Build top-10 sorted array (pinned first, then by launch_count desc)
top10=$(jq -c '
  .apps
  | sort_by([if .pinned then 0 else 1 end, -(.launch_count)])
  | .[0:10]
' "$APPS_FILE")

# Build each module entry as a jq object, then merge into a single object
build_modules() {
  local modules_obj='{}'
  for i in $(seq 0 9); do
    local key="custom/app${i}"
    local app
    app=$(echo "$top10" | jq -c ".[$i] // empty")
    local entry
    if [[ -n "$app" ]]; then
      local exec_val name glyph id
      exec_val=$(echo "$app" | jq -r '.exec')
      name=$(echo "$app"     | jq -r '.name')
      glyph=$(echo "$app"    | jq -r '.glyph // .icon // ""')
      id=$(echo "$app"       | jq -r '.id')
      entry=$(jq -n \
        --arg exec   "$LAUNCH_SCRIPT $exec_val $name --print-icon $glyph" \
        --arg click  "$LAUNCH_SCRIPT $exec_val $name" \
        --arg rclick "$CTX_SCRIPT $id" \
        '{
          "exec":            $exec,
          "return-type":     "json",
          "interval":        "once",
          "on-click":        $click,
          "on-click-right":  $rclick
        }')
    else
      entry='{"exec":"echo '"'"'{\"text\":\"·\",\"tooltip\":\"empty slot\"}'"'"'","return-type":"json","interval":"once"}'
    fi
    modules_obj=$(echo "$modules_obj" | jq --arg k "$key" --argjson v "$entry" '. + {($k): $v}')
  done

  # Add-app button
  local add_entry
  add_entry=$(jq -n \
    --arg exec  "echo '{\"text\":\" +\",\"tooltip\":\"Add app\"}'" \
    --arg click "$ADD_SCRIPT" \
    '{"exec": $exec, "return-type": "json", "interval": "once", "on-click": $click}')
  modules_obj=$(echo "$modules_obj" | jq --argjson v "$add_entry" '. + {"custom/add": $v}')

  echo "$modules_obj"
}

modules=$(build_modules)

# Build structural config and merge module definitions
# margin-top: ~2.5cm from top (38 original + 57 for 1.5cm shift = 95px at 96dpi)
# margin-left: ~5cm from left (113 original + 76 for 2cm shift = 189px at 96dpi)
jq -n \
  --argjson mods "$modules" \
  '{
    "layer":                   "top",
    "position":                "top",
    "height":                  88,
    "margin-top":              95,
    "margin-left":             189,
    "exclusive":               false,
    "passthrough":             false,
    "gtk-layer-shell":         true,
    "reload_style_on_change":  true,
    "modules-left": (
      [range(10) | "custom/app\(.)"] + ["custom/add"]
    ),
    "modules-center": [],
    "modules-right":  []
  } + $mods' > "$CONFIG_OUT"

log_info "Launchers updated: $CONFIG_OUT"
