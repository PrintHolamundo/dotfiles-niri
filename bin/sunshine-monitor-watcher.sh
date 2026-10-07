#!/usr/bin/env bash
# sunshine-monitor-watcher.sh
# Continuously monitors monitor status.
# If DP-1 is turned off or disconnected, activates DP-3 so Sunshine always has a live display.
# If DP-1 is turned back on and streaming is NOT active, turns off DP-3 for clean local usage.

set -u

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${UID:-1000}}"

detect_de() {
    local de="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
    if   [[ "$de" =~ [Hh]yprland ]] || pgrep -x Hyprland >/dev/null 2>&1; then echo "Hyprland"
    elif [[ "$de" =~ [Nn]iri ]]     || pgrep -x niri >/dev/null 2>&1;     then echo "Niri"
    elif [[ "$de" =~ [Kk][Dd][Ee]|[Pp]lasma ]] || pgrep -x kwin_wayland >/dev/null 2>&1; then echo "KDE"
    else echo "Unknown"
    fi
}

resolve_sockets() {
    if [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
        for sock in $(find "$XDG_RUNTIME_DIR/hypr" -maxdepth 2 -name ".socket.sock" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk '{print $2}'); do
            sig=$(basename "$(dirname "$sock")")
            if hyprctl -i "$sig" version >/dev/null 2>&1; then
                export HYPRLAND_INSTANCE_SIGNATURE="$sig"
                break
            fi
        done
    fi
    if [ -z "${NIRI_SOCKET:-}" ]; then
        NS=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name "niri.*.sock" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | awk '{print $2}')
        [ -n "$NS" ] && export NIRI_SOCKET="$NS"
    fi
    if [ -z "${WAYLAND_DISPLAY:-}" ]; then
        WL=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name "wayland-*" ! -name "*.lock" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | awk '{print $2}' | xargs -r basename || true)
        [ -n "$WL" ] && export WAYLAND_DISPLAY="$WL"
    fi
}

LOG="$HOME/.local/share/sunshine-macbook.log"
mkdir -p "$(dirname "$LOG")"

echo "$(date -Iseconds) [WATCHER] Started sunshine monitor watcher." >> "$LOG"

while true; do
    sleep 2

    # If actively streaming via Sunshine, leave display management to connect/disconnect scripts
    if [ -f /tmp/sunshine_streaming.lock ]; then
        continue
    fi

    resolve_sockets
    DE=$(detect_de)

    if [ "$DE" = "Niri" ]; then
        command -v niri >/dev/null 2>&1 || continue
        OUTPUTS=$(niri msg -j outputs 2>/dev/null || echo "{}")
        [ "$OUTPUTS" = "{}" ] && continue

        # Check if ANY physical display (DP-1, HDMI-A-1) is present and logically active
        PHYSICAL_ACTIVE=$(echo "$OUTPUTS" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    for name in ['DP-1', 'HDMI-A-1']:
        out = d.get(name)
        if out and out.get('logical') is not None:
            print('true')
            sys.exit(0)
except Exception:
    pass
print('false')
" 2>/dev/null || echo "false")

        # Check if DP-3 is currently enabled
        DP3_ACTIVE=$(echo "$OUTPUTS" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    dp3 = d.get('DP-3')
    if dp3 and dp3.get('logical') is not None:
        print('true')
        sys.exit(0)
except Exception:
    pass
print('false')
" 2>/dev/null || echo "false")

        if [ "$PHYSICAL_ACTIVE" = "false" ]; then
            # No physical monitor is active (true headless). DP-3 MUST BE ON!
            if [ "$DP3_ACTIVE" = "false" ]; then
                echo "$(date -Iseconds) [WATCHER-NIRI] All physical displays are OFF. Activating DP-3..." >> "$LOG"
                niri msg output DP-3 on >> "$LOG" 2>&1 || true
                niri msg output DP-3 mode "1680x1050@59.954" >> "$LOG" 2>&1 || true
                niri msg output DP-3 scale 1.0 >> "$LOG" 2>&1 || true
                niri msg output DP-3 position set 0 0 >> "$LOG" 2>&1 || true
                niri msg action focus-monitor DP-3 >> "$LOG" 2>&1 || true
            fi
        else
            # A physical monitor (DP-1 or HDMI-A-1) is active. DP-3 should be OFF for local usage.
            if [ "$DP3_ACTIVE" = "true" ]; then
                echo "$(date -Iseconds) [WATCHER-NIRI] Physical display is active. Deactivating DP-3..." >> "$LOG"
                niri msg output DP-3 off >> "$LOG" 2>&1 || true
            fi
        fi

    elif [ "$DE" = "Hyprland" ]; then
        command -v hyprctl >/dev/null 2>&1 || continue
        MONS=$(hyprctl monitors -j 2>/dev/null || echo "[]")
        [ "$MONS" = "[]" ] && continue

        PHYSICAL_ACTIVE=$(echo "$MONS" | python3 -c "
import sys, json
try:
    mons = json.load(sys.stdin)
    if any(m.get('name') in ['DP-1', 'HDMI-A-1'] and not m.get('disabled', False) for m in mons):
        print('true')
        sys.exit(0)
except Exception:
    pass
print('false')
" 2>/dev/null || echo "false")

        DP3_ACTIVE=$(echo "$MONS" | python3 -c "
import sys, json
try:
    mons = json.load(sys.stdin)
    if any(m.get('name') == 'DP-3' and not m.get('disabled', False) for m in mons):
        print('true')
        sys.exit(0)
except Exception:
    pass
print('false')
" 2>/dev/null || echo "false")

        if [ "$PHYSICAL_ACTIVE" = "false" ]; then
            if [ "$DP3_ACTIVE" = "false" ]; then
                echo "$(date -Iseconds) [WATCHER-HYPR] All physical displays are OFF. Activating DP-3..." >> "$LOG"
                hyprctl eval 'hl.monitor({ output = "DP-3", mode = "1680x1050@59.95", position = "0x0", scale = 1, disabled = false })' >> "$LOG" 2>&1 || true
                hyprctl dispatch focusmonitor DP-3 >> "$LOG" 2>&1 || true
            fi
        else
            if [ "$DP3_ACTIVE" = "true" ]; then
                echo "$(date -Iseconds) [WATCHER-HYPR] Physical display is active. Deactivating DP-3..." >> "$LOG"
                hyprctl eval 'hl.monitor({ output = "DP-3", mode = "1680x1050@59.95", position = "3440x0", scale = 1, disabled = true })' >> "$LOG" 2>&1 || true
            fi
        fi
    fi
done
