#!/usr/bin/env bash
# Show minimized windows (special workspace) in rofi; restore selected to current workspace.

windows=$(hyprctl clients -j | jq -r '
  .[] | select(.workspace.name | startswith("special"))
  | "\(.address)\t\(.class): \(.title)"
')

[ -z "$windows" ] && { rofi -e "No minimized windows"; exit 0; }

chosen=$(echo "$windows" | awk -F'\t' '{print $2}' |
  rofi -dmenu -i -p "Restore" -theme-str 'window {width: 40%;}')

[ -z "$chosen" ] && exit 0

addr=$(echo "$windows" | grep -F "$chosen" | head -1 | awk -F'\t' '{print $1}')
hyprctl dispatch movetoworkspace "e+0,address:$addr"
hyprctl dispatch focuswindow "address:$addr"
