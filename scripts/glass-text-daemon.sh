#!/usr/bin/env bash
# glass-text-daemon.sh — Writes background brightness mode to /tmp/glass-mode
#
# Reads the current background color from hypr-edge-bg's cache (no grim needed).
# Computes luminance from the hex in the filename.
# If luminance > THRESHOLD → "light", else → "dark".

trap '' HUP

LOCKFILE="/tmp/glass-text-daemon.lock"
MODEFILE="/tmp/glass-mode"
BG_CACHE="/tmp/hypr-edge-bg"
THRESHOLD=140
LAST_MODE=""
INTERVAL=0.25

# ── Prevent duplicate instances (PID-based, survives SIGKILL) ────────────────
if [[ -f "$LOCKFILE" ]]; then
    old_pid=$(cat "$LOCKFILE" 2>/dev/null)
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        echo "Glass text daemon already running (pid $old_pid), exiting." >&2
        exit 0
    fi
fi
echo $$ > "$LOCKFILE"

cleanup() { rm -f "$LOCKFILE"; }
trap 'cleanup' EXIT

# ── Write initial mode file ──────────────────────────────────────────────────
if [[ ! -f "$MODEFILE" ]]; then
    echo "dark" > "$MODEFILE"
fi

update_cache_mode() {
    # Rewrite all waybar cache files with the new glass-mode so they're
    # current when waybar re-reads on signal
    local m=$1 CACHE_DIR="/tmp/waybar-cache"
    [[ -d "$CACHE_DIR" ]] || return
    for f in "$CACHE_DIR"/*; do
        [[ -f "$f" ]] || continue
        local content
        content=$(cat "$f" 2>/dev/null)
        [[ -z "$content" ]] && continue
        # Replace "class":"<anything>" with new mode (preserve "inactive" and "current" suffixes)
        sed -i "s/\"class\":\"[^\"]*dark[^\"]*\"/\"class\":\"$m\"/;s/\"class\":\"[^\"]*light[^\"]*\"/\"class\":\"$m\"/" "$f" 2>/dev/null
    done
}

set_mode() {
    echo "$1" > "$MODEFILE"
    update_cache_mode "$1"
    pkill -RTMIN+10 waybar 2>/dev/null || true
}

hex_luminance() {
    # Compute perceived luminance (0-255) from hex string
    local hex=$1
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    # ITU-R BT.601 luma
    echo $(( (r * 299 + g * 587 + b * 114) / 1000 ))
}

echo "Glass text daemon started (reading from hypr-edge-bg cache)"

LAST_HEX=""

while true; do
    # Single subprocess: get newest bg file
    hex=$(ls -t "$BG_CACHE"/bg_??????.png 2>/dev/null | head -1)
    if [[ -n "$hex" ]]; then
        hex=${hex##*/bg_}
        hex=${hex%.png}
        # Only recompute if hex changed
        if [[ "$hex" != "$LAST_HEX" && ${#hex} -eq 6 ]]; then
            LAST_HEX=$hex
            r=$((16#${hex:0:2}))
            g=$((16#${hex:2:2}))
            b=$((16#${hex:4:2}))
            lum=$(( (r * 299 + g * 587 + b * 114) / 1000 ))
            if (( lum > THRESHOLD )); then
                mode="light"
            else
                mode="dark"
            fi
            if [[ "$mode" != "$LAST_MODE" ]]; then
                set_mode "$mode"
                LAST_MODE="$mode"
            fi
        fi
    fi
    sleep 0.5
done
