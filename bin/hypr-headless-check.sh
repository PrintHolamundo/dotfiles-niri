#!/usr/bin/env bash
set -euo pipefail

LOG="$HOME/.local/share/sunshine-macbook.log"
mkdir -p "$(dirname "$LOG")"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${UID:-1000}}"

if [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
    _SIG=$(find "$XDG_RUNTIME_DIR/hypr" -maxdepth 2 -name ".socket.sock" -printf '%h\n' 2>/dev/null | head -n1 | xargs -r basename || true)
    [ -n "${_SIG:-}" ] && export HYPRLAND_INSTANCE_SIGNATURE="$_SIG"
fi

command -v hyprctl >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

MON_USER="$HOME/.config/hypr/monitors_user.lua"

# Clean stale locks from prior sessions
rm -f /tmp/sunshine_streaming.lock

# Clean obsolete virtual headless display if still present
if hyprctl monitors all -j 2>/dev/null | jq -e '.[] | select(.name == "HEADLESS-1")' >/dev/null 2>&1; then
    hyprctl output remove HEADLESS-1 2>/dev/null || true
fi

sleep 0.5

# Check if ANY physical output (DP-1, HDMI-A-1) is logically active from Hyprland's config
PHYSICAL_ACTIVE=$(hyprctl monitors -j 2>/dev/null | python3 -c "
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

echo "$(date -Iseconds) [BOOT-CHECK-HYPR] Hyprland started. Physical display active: $PHYSICAL_ACTIVE" >> "$LOG"

if [ "$PHYSICAL_ACTIVE" = "true" ]; then
    # Saved layout from monitors_user.lua is already active! Do NOT overwrite it.
    echo "$(date -Iseconds) [BOOT-CHECK-HYPR] Saved display layout active. Ensuring DP-3 dummy is off..." >> "$LOG"
    hyprctl eval 'hl.monitor({ output = "DP-3", disabled = true })' >> "$LOG" 2>&1 || true
else
    # Neither DP-1 nor HDMI-A-1 is currently active.
    # Check if DP-1 or HDMI-A-1 is physically detected in port:
    DP1_DETECTED=$(hyprctl monitors all -j 2>/dev/null | jq -r '.[] | select(.name == "DP-1") | .name' 2>/dev/null || echo "")
    HDMI1_DETECTED=$(hyprctl monitors all -j 2>/dev/null | jq -r '.[] | select(.name == "HDMI-A-1") | .name' 2>/dev/null || echo "")

    if [ -n "$DP1_DETECTED" ]; then
        echo "$(date -Iseconds) [BOOT-CHECK-HYPR] Activating fallback DP-1..." >> "$LOG"
        cat > "$MON_USER" << 'LUA'
-- sunshine local override (fallback)
hl.monitor({ output = "DP-3",    disabled = true })
hl.monitor({ output = "HDMI-A-1", disabled = true })
hl.monitor({ output = "DP-1",    mode = "3440x1440@144.00", position = "0x0", scale = 1.25, disabled = false })
LUA
        hyprctl reload >> "$LOG" 2>&1 || true
        hyprctl dispatch focusmonitor DP-1 >> "$LOG" 2>&1 || true
    elif [ -n "$HDMI1_DETECTED" ]; then
        echo "$(date -Iseconds) [BOOT-CHECK-HYPR] Activating fallback HDMI-A-1..." >> "$LOG"
        cat > "$MON_USER" << 'LUA'
-- sunshine local override (fallback)
hl.monitor({ output = "DP-3",    disabled = true })
hl.monitor({ output = "DP-1",    disabled = true })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "0x0", scale = 1.0, disabled = false })
LUA
        hyprctl reload >> "$LOG" 2>&1 || true
        hyprctl dispatch focusmonitor HDMI-A-1 >> "$LOG" 2>&1 || true
    else
        # Pure headless remote boot with no physical monitor:
        # Enable DP-3 dummy plug so Sunshine has an active output to capture
        echo "$(date -Iseconds) [BOOT-CHECK-HYPR] Pure headless boot. Activating DP-3..." >> "$LOG"
        cat > "$MON_USER" << 'LUA'
-- sunshine headless boot override
hl.monitor({ output = "DP-1",    disabled = true })
hl.monitor({ output = "HDMI-A-1", disabled = true })
hl.monitor({ output = "DP-3",    mode = "1680x1050@59.95", position = "0x0", scale = 1.0, disabled = false })
LUA
        hyprctl reload >> "$LOG" 2>&1 || true
        hyprctl dispatch focusmonitor DP-3 >> "$LOG" 2>&1 || true
    fi
fi

exit 0
