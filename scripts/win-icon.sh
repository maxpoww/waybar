#!/usr/bin/env bash
# Output JSON for active window icon module
m=$(cat /tmp/glass-mode 2>/dev/null || echo dark)
class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' 2>/dev/null)

# Map window class to nerd font icon (using printf for reliable unicode)
case "${class,,}" in
  kitty|foot|alacritty)  icon=$'\uf120' ;;
  firefox|firedragon)    icon=$'\U000f0239' ;;
  chromium|google-chrome) icon=$'\uf268' ;;
  code|code-oss)         icon=$'\U000f0a1e' ;;
  nautilus|thunar)       icon=$'\uf413' ;;
  spotify)               icon=$'\uf1bc' ;;
  discord)               icon=$'\U000f066f' ;;
  telegram*)             icon=$'\uf2c6' ;;
  slack)                 icon=$'\U000f04b1' ;;
  obsidian)              icon=$'\U000f1c67' ;;
  *)                     icon=$'\uf2d0' ;;
esac

printf '{"text":"%s","class":"%s","tooltip":"%s"}' "$icon" "$m" "$class"
