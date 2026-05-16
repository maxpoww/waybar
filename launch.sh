#!/usr/bin/env bash
# Launch waybar + glass-text daemon
# Single bar with class-based color switching (no reload, no flicker)

DAEMON="$HOME/.config/waybar/scripts/glass-text-daemon.sh"
PIDFILE="/tmp/glass-text-daemon.pid"

# Kill ALL previous daemon instances
pkill -f glass-text-daemon 2>/dev/null
pkill -f workspace-daemon 2>/dev/null
pkill waybar 2>/dev/null
sleep 0.3
pkill -f glass-text-daemon 2>/dev/null
pkill -f workspace-daemon 2>/dev/null
rm -f "$PIDFILE" /tmp/glass-text-daemon.lock /tmp/glass-mode
rm -rf /tmp/waybar-cache

# Start waybar
waybar &

# Wait until waybar is actually running
for _ in $(seq 1 30); do
    pgrep -f waybar &>/dev/null && break
    sleep 0.1
done

# Start daemon with auto-restart (survives crashes + exec-once parent exit)
(
    trap '' HUP
    while pgrep -f waybar &>/dev/null; do
        "$DAEMON"
        sleep 1
    done
) &
echo $! > "$PIDFILE"
disown $!

# Start workspace cache daemon
(
    trap '' HUP
    while pgrep -f waybar &>/dev/null; do
        "$HOME/.config/waybar/scripts/workspace-daemon.sh"
        sleep 1
    done
) &
disown $!
