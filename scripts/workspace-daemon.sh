#!/usr/bin/env bash
# Single daemon that polls hyprctl once per second and writes
# per-module output files. Waybar modules read these with cat (cheap).
CACHE_DIR="/tmp/waybar-cache"
mkdir -p "$CACHE_DIR"

while true; do
  m=$(cat /tmp/glass-mode 2>/dev/null || echo dark)
  active=$(hyprctl activeworkspace -j 2>/dev/null)
  workspaces=$(hyprctl workspaces -j 2>/dev/null)
  activewin=$(hyprctl activewindow -j 2>/dev/null)

  a=$(echo "$active" | jq -r '.id')
  ws_ids=$(echo "$workspaces" | jq -r '.[].id')
  title=$(echo "$activewin" | jq -r '.title // empty' 2>/dev/null)

  # ws-current
  printf '{"text":"%s","class":"%s"}' "$a" "$m" > "$CACHE_DIR/ws-current"

  # ws-1 through ws-9
  for i in 1 2 3 4 5 6 7 8 9; do
    if echo "$ws_ids" | grep -qx "$i"; then
      if [ "$a" = "$i" ]; then
        printf '{"text":"%s","class":"%s"}' "$i" "$m" > "$CACHE_DIR/ws-$i"
      else
        printf '{"text":"%s","class":"inactive"}' "$i" > "$CACHE_DIR/ws-$i"
      fi
    else
      echo "" > "$CACHE_DIR/ws-$i"
    fi
  done

  # window title
  printf '{"text":"%s","class":"%s"}' "${title:-}" "$m" > "$CACHE_DIR/window"

  # win-move-1 through win-move-9 (move-to-workspace targets)
  for i in 1 2 3 4 5 6 7 8 9; do
    if echo "$ws_ids" | grep -qx "$i"; then
      if [ "$a" = "$i" ]; then
        printf '{"text":"%s","class":"%s current"}' "$i" "$m" > "$CACHE_DIR/win-move-$i"
      else
        printf '{"text":"%s","class":"%s"}' "$i" "$m" > "$CACHE_DIR/win-move-$i"
      fi
    else
      echo "" > "$CACHE_DIR/win-move-$i"
    fi
  done

  sleep 1
done
