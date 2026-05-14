#!/usr/bin/env bash
# Launch waybar + glass-text daemon
# Single bar with class-based color switching (no reload, no flicker)

DAEMON="$HOME/.config/waybar/scripts/glass-text-daemon.sh"
PIDFILE="/tmp/glass-text-daemon.pid"

# Kill previous instances using saved PID (avoids matching unrelated processes)
if [[ -f "$PIDFILE" ]]; then
    old_pid=$(cat "$PIDFILE" 2>/dev/null)
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        kill "$old_pid" 2>/dev/null
        sleep 0.2
    fi
    rm -f "$PIDFILE"
fi

pkill waybar 2>/dev/null
sleep 0.3
rm -f /tmp/glass-text-daemon.lock /tmp/glass-mode

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
