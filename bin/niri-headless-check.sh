#!/usr/bin/env bash
set -euo pipefail

LOG="$HOME/.local/share/sunshine-macbook.log"
mkdir -p "$(dirname "$LOG")"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${UID:-1000}}"

if [ -z "${NIRI_SOCKET:-}" ]; then
    NS=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name "niri.*.sock" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | awk '{print $2}')
    [ -n "$NS" ] && export NIRI_SOCKET="$NS"
fi

command -v niri >/dev/null 2>&1 || exit 0

# Clean stale locks
rm -f /tmp/sunshine_streaming.lock

sleep 0.5

# Check if ANY physical output (DP-1, HDMI-A-1) is logically active from Niri's config (cfg/display.kdl)
PHYSICAL_ACTIVE=$(niri msg -j outputs 2>/dev/null | python3 -c "
import sys, json
try:
    outputs = json.load(sys.stdin)
    for name in ['DP-1', 'HDMI-A-1']:
        out = outputs.get(name)
        if out and out.get('logical') is not None:
            print('true')
            sys.exit(0)
except Exception:
    pass
print('false')
" 2>/dev/null || echo "false")

echo "$(date -Iseconds) [BOOT-CHECK-NIRI] Niri started. Physical display active: $PHYSICAL_ACTIVE" >> "$LOG"

if [ "$PHYSICAL_ACTIVE" = "true" ]; then
    # The user's saved configuration from display.kdl is active. Keep it and ensure dummy DP-3 is off!
    echo "$(date -Iseconds) [BOOT-CHECK-NIRI] Saved display layout active. Ensuring DP-3 dummy is off..." >> "$LOG"
    niri msg output DP-3 off >> "$LOG" 2>&1 || true
else
    # Neither DP-1 nor HDMI-A-1 is currently active.
    # Check if a physical cable is connected to DP-1 or HDMI-A-1:
    DP1_STATUS=$(cat /sys/class/drm/card*-DP-1/status 2>/dev/null | head -n1 || echo "disconnected")
    HDMI1_STATUS=$(cat /sys/class/drm/card*-HDMI-A-1/status 2>/dev/null | head -n1 || echo "disconnected")

    if [ "$DP1_STATUS" = "connected" ]; then
        echo "$(date -Iseconds) [BOOT-CHECK-NIRI] Activating fallback DP-1..." >> "$LOG"
        niri msg output DP-1 on >> "$LOG" 2>&1 || true
        niri msg output DP-1 mode "3440x1440@144.000" >> "$LOG" 2>&1 || true
        niri msg output DP-1 scale 1.25 >> "$LOG" 2>&1 || true
        niri msg output DP-1 position set 0 0 >> "$LOG" 2>&1 || true
        niri msg action focus-monitor DP-1 >> "$LOG" 2>&1 || true
        niri msg output DP-3 off >> "$LOG" 2>&1 || true
    elif [ "$HDMI1_STATUS" = "connected" ]; then
        echo "$(date -Iseconds) [BOOT-CHECK-NIRI] Activating fallback HDMI-A-1..." >> "$LOG"
        niri msg output HDMI-A-1 on >> "$LOG" 2>&1 || true
        niri msg output HDMI-A-1 mode "1920x1080@60.000" >> "$LOG" 2>&1 || true
        niri msg output HDMI-A-1 scale 1.0 >> "$LOG" 2>&1 || true
        niri msg output HDMI-A-1 position set 0 0 >> "$LOG" 2>&1 || true
        niri msg action focus-monitor HDMI-A-1 >> "$LOG" 2>&1 || true
        niri msg output DP-3 off >> "$LOG" 2>&1 || true
    else
        # Pure headless boot: enable DP-3 dummy plug so Sunshine has an active output
        echo "$(date -Iseconds) [BOOT-CHECK-NIRI] No physical display connected (headless boot). Activating DP-3..." >> "$LOG"
        niri msg output DP-3 on >> "$LOG" 2>&1 || true
        niri msg output DP-3 mode "1680x1050@59.954" >> "$LOG" 2>&1 || true
        niri msg output DP-3 scale 1.0 >> "$LOG" 2>&1 || true
        niri msg output DP-3 position set 0 0 >> "$LOG" 2>&1 || true
        niri msg action focus-monitor DP-3 >> "$LOG" 2>&1 || true
    fi
fi

exit 0
