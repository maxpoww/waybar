#!/usr/bin/env bash
# glass-text-daemon.sh — Writes background brightness mode to /tmp/glass-mode
#
# How it works:
#   1. Every INTERVAL seconds, capture a screenshot of the bar region
#   2. Compute mean luminance (0-255)
#   3. If luminance > THRESHOLD → write "light", else → write "dark"
#   4. Waybar custom modules read /tmp/glass-mode and output it as a CSS class
#
# Usage:
#   ./glass-text-daemon.sh [INTERVAL_SECONDS]   # default: 0.25 seconds
#   ./glass-text-daemon.sh --once               # measure once, apply, exit
#
# Requirements: grim, imagemagick (magick), hyprctl, jq

trap '' HUP

TMPIMG="/tmp/glass-bar-sample.png"
LOCKFILE="/tmp/glass-text-daemon.lock"
MODEFILE="/tmp/glass-mode"
THRESHOLD=140
LAST_MODE=""
ONCE=0

# ── Parse arguments ───────────────────────────────────────────────────────────
if [[ "$1" == "--once" || "$1" == "-o" ]]; then
    ONCE=1
    INTERVAL=0
elif [[ -n "$1" && "$1" =~ ^[0-9.]+$ ]]; then
    INTERVAL="$1"
else
    INTERVAL=0.25
fi

# ── Ensure Wayland compositor env vars are available ─────────────────────────
if [[ -z "$WAYLAND_DISPLAY" ]]; then
    export WAYLAND_DISPLAY="wayland-1"
fi

if [[ -z "$XDG_RUNTIME_DIR" ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

if [[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    for candidate_dir in "$XDG_RUNTIME_DIR/hypr" "/tmp/hypr"; do
        [[ -d "$candidate_dir" ]] || continue
        for entry in "$candidate_dir"/*/; do
            [[ -d "$entry" ]] || continue
            SIG="${entry%/}"
            SIG="${SIG##*/}"
            export HYPRLAND_INSTANCE_SIGNATURE="$SIG"
            break 2
        done
    done
fi

# ── Prevent duplicate instances ──────────────────────────────────────────────
if [[ "$ONCE" -eq 0 ]]; then
    exec 9>"$LOCKFILE"
    if ! flock -n 9; then
        echo "Glass text daemon already running, exiting." >&2
        exit 0
    fi
    echo $$ >&9
fi

cleanup() { rm -f "$LOCKFILE" "$TMPIMG"; }
trap 'cleanup' EXIT

# ── Sanity checks ─────────────────────────────────────────────────────────────
for tool in grim magick hyprctl jq; do
    if ! command -v "$tool" &>/dev/null; then
        echo "ERROR: '$tool' not found in PATH. Cannot run daemon." >&2
        exit 1
    fi
done

# ── Wait for Hyprland to be ready (important at boot) ────────────────────────
for _ in $(seq 1 50); do
    hyprctl monitors -j &>/dev/null && break
    sleep 0.2
done

# ── Wait for grim/screencopy to be ready (compositor may lag at boot) ────────
for _ in $(seq 1 30); do
    grim -g "0,0 1x1" /tmp/glass-grim-test.png 2>/dev/null && break
    sleep 0.3
done
rm -f /tmp/glass-grim-test.png

# ── Write initial mode file ──────────────────────────────────────────────────
if [[ ! -f "$MODEFILE" ]]; then
    echo "dark" > "$MODEFILE"
fi

# ── Monitor geometry ──────────────────────────────────────────────────────────
get_monitor_width() {
    local json
    json=$(hyprctl monitors -j 2>/dev/null)
    if [[ -z "$json" ]]; then
        return 1
    fi
    echo "$json" | jq -r '
        (map(select(.focused)) | first // .[0])
        | (.width / .scale | floor)
    ' 2>/dev/null
}

# ── Screenshot + brightness measurement ───────────────────────────────────────
get_bar_brightness() {
    local LOGICAL_W
    LOGICAL_W=$(get_monitor_width)
    if [[ -z "$LOGICAL_W" || "$LOGICAL_W" == "null" ]]; then
        LOGICAL_W=1600
    fi

    local BAR_MARGIN_TOP=6
    local BAR_HEIGHT=38
    local INSET_X=60
    local INSET_Y=4

    local x=$INSET_X
    local y=$(( BAR_MARGIN_TOP + INSET_Y ))
    local w=$(( LOGICAL_W - INSET_X * 2 ))
    local h=$(( BAR_HEIGHT - INSET_Y * 2 ))

    if (( w <= 0 )); then
        return 1
    fi

    grim -g "${x},${y} ${w}x${h}" "$TMPIMG" 2>/dev/null || {
        return 1
    }

    local mean
    mean=$(magick "$TMPIMG" -colorspace Gray -format "%[fx:int(mean*255)]" info: 2>/dev/null)

    if [[ ! "$mean" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    echo "$mean"
}

# ── Apply mode (signal-only, no reload) ──────────────────────────────────────
set_mode() {
    echo "$1" > "$MODEFILE"
    pkill -RTMIN+10 waybar 2>/dev/null || true
}

# ── Main loop ─────────────────────────────────────────────────────────────────
echo "Glass text daemon started (interval: ${INTERVAL}s, threshold: $THRESHOLD)"

while true; do
    brightness=$(get_bar_brightness)

    if [[ -z "$brightness" ]]; then
        [[ "$ONCE" -eq 1 ]] && exit 1
        sleep "$INTERVAL"
        continue
    fi

    if (( brightness > THRESHOLD )); then
        mode="light"
    else
        mode="dark"
    fi

    if [[ "$ONCE" -eq 1 ]]; then
        set_mode "$mode"
        printf "Brightness: %3d/255 → %s\n" "$brightness" "$mode"
        exit 0
    fi

    if [[ "$mode" != "$LAST_MODE" ]]; then
        set_mode "$mode"
        LAST_MODE="$mode"
        printf "Brightness: %3d/255 → %s\n" "$brightness" "$mode"
    fi

    sleep "$INTERVAL"
done
