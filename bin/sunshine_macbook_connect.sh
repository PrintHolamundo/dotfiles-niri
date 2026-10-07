#!/usr/bin/env bash
# sunshine_macbook_connect.sh
# Called by Sunshine when a client connects.
# Action:
#   Hyprland: enable DP-3 at 1680x1050@59.95 at 3440x0 scale 1.0, migrate workspaces, disable DP-1 & HDMI-A-1
#   KDE:      enable DP-3 at 1680x1050@60 scale 1.0, disable other outputs atomically
#   Niri:     enable DP-3 at 1680x1050@59.954 scale 1.0, disable DP-1 & HDMI-A-1
set -euo pipefail

LOG="$HOME/.local/share/sunshine-macbook.log"
mkdir -p "$(dirname "$LOG")"
exec >> "$LOG" 2>&1

# Concurrency lock: serialize rapid connect/disconnect events cleanly
exec 200>/tmp/sunshine_macbook_switch.lock
flock -w 10 200 || { echo "$(date -Iseconds) [CONNECT] Lock timeout; continuing anyway"; }

# ── Environment setup ──────────────────────────────────────────────────────────
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${UID:-1000}}"

# Resolve active Hyprland socket by checking live response
if [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
    for sock in $(find "$XDG_RUNTIME_DIR/hypr" -maxdepth 2 -name ".socket.sock" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk '{print $2}'); do
        sig=$(basename "$(dirname "$sock")")
        if hyprctl -i "$sig" version >/dev/null 2>&1; then
            export HYPRLAND_INSTANCE_SIGNATURE="$sig"
            break
        fi
    done
fi

# Resolve Wayland display socket
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    WL=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name "wayland-*" ! -name "*.lock" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | awk '{print $2}' | xargs -r basename || true)
    [ -n "$WL" ] && export WAYLAND_DISPLAY="$WL"
fi

# Resolve Niri socket
if [ -z "${NIRI_SOCKET:-}" ]; then
    NS=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name "niri.*.sock" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | awk '{print $2}')
    [ -n "$NS" ] && export NIRI_SOCKET="$NS"
fi

# ── Desktop environment detection ─────────────────────────────────────────────
detect_de() {
    local de="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
    if   [[ "$de" =~ [Hh]yprland ]];                   then echo "Hyprland"
    elif pgrep -x Hyprland >/dev/null 2>&1;             then echo "Hyprland"
    elif [[ "$de" =~ [Kk][Dd][Ee]|[Pp]lasma ]];       then echo "KDE"
    elif pgrep -x kwin_wayland >/dev/null 2>&1;         then echo "KDE"
    elif [[ "$de" =~ [Nn]iri ]];                       then echo "Niri"
    elif pgrep -x niri >/dev/null 2>&1;                 then echo "Niri"
    else                                                     echo "Unknown"
    fi
}
DE=$(detect_de)
echo "$(date -Iseconds) [CONNECT] Client connected (DE=$DE)"

# ── Streaming lock (stops ryoku-monitor from fighting us) ──────────────────────
touch /tmp/sunshine_streaming.lock

# ── Hyprland ──────────────────────────────────────────────────────────────────
if [ "$DE" = "Hyprland" ]; then
    if ! command -v hyprctl >/dev/null 2>&1; then
        echo "$(date -Iseconds) [CONNECT-HYPR] ERROR: hyprctl not found"
        exit 0
    fi

    # Capture current active workspace to keep focus on the user's apps
    ACTIVE_WS=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null || echo "1")
    mkdir -p "$HOME/.local/state"
    echo "$ACTIVE_WS" > "$HOME/.local/state/sunshine_active_ws.txt"

    MON_USER="$HOME/.config/hypr/monitors_user.lua"

    # CRITICAL: Always ENABLE DP-3 at 3440x0 (non-overlapping with DP-1 at 0x0)
    # Using position 3440x0 prevents the "DP-3 overlaps with other monitor(s)" warning.
    # Also: Use `hyprctl eval` to apply live instead of `hyprctl reload` which tears down the whole session.
    echo "$(date -Iseconds) [CONNECT-HYPR] Enabling DP-3 live (1680x1050@59.95, position 3440x0, scale 1.0)..."
    hyprctl eval 'hl.monitor({ output = "DP-3", mode = "1680x1050@59.95", position = "3440x0", scale = 1, disabled = false })' >/dev/null 2>&1 || true

    # Wait up to 2 seconds for DP-3 to be confirmed active
    for i in $(seq 1 20); do
        if hyprctl monitors -j 2>/dev/null \
           | python3 -c "import sys,json; sys.exit(0 if any(m['name']=='DP-3' and not m['disabled'] for m in json.load(sys.stdin)) else 1)" \
           2>/dev/null; then
            echo "$(date -Iseconds) [CONNECT-HYPR] DP-3 active ✓"
            break
        fi
        sleep 0.1
    done

    # Migrate all active workspaces and their open windows to DP-3 so all user apps are visible
    echo "$(date -Iseconds) [CONNECT-HYPR] Migrating workspaces to DP-3..."
    for ws in $(hyprctl workspaces -j 2>/dev/null | jq -r '.[].id' 2>/dev/null || true); do
        [ -z "$ws" ] && continue
        hyprctl dispatch "hl.dsp.workspace.move({ workspace = $ws, monitor = \"DP-3\" })" >/dev/null 2>&1 || true
    done

    # Focus active workspace on DP-3
    hyprctl dispatch "hl.dsp.focus({ workspace = $ACTIVE_WS })" >/dev/null 2>&1 || true
    hyprctl dispatch focusmonitor DP-3 >/dev/null 2>&1 || true

    # Now that DP-3 is active and workspaces are on it, safely disable DP-1 and HDMI-A-1
    echo "$(date -Iseconds) [CONNECT-HYPR] Disabling local monitors (DP-1, HDMI-A-1)..."
    hyprctl eval 'hl.monitor({ output = "DP-1", mode = "3440x1440@144.00", position = "0x0", scale = 1.3333333, disabled = true })' >/dev/null 2>&1 || true
    hyprctl eval 'hl.monitor({ output = "HDMI-A-1", disabled = true })' >/dev/null 2>&1 || true

    # Persist layout to monitors_user.lua for reboot durability (DO NOT run hyprctl reload!)
    cat > "$MON_USER" << 'LUA'
-- sunshine remote override (connect)
hl.monitor({ output = "DP-3",    mode = "1680x1050@59.95", position = "3440x0", scale = 1, disabled = false })
hl.monitor({ output = "HDMI-A-1", disabled = true })
hl.monitor({ output = "DP-1",    mode = "3440x1440@144.00", position = "0x0", scale = 1.3333333, disabled = true })
LUA

    # Software cursor so Moonlight can capture it
    hyprctl eval "hl.config({ cursor = { no_hardware_cursors = true } })" >/dev/null 2>&1 || true

    # Pause idle daemon during streaming
    pkill -STOP -x hypridle 2>/dev/null || true

    echo "$(date -Iseconds) [CONNECT-HYPR] Done."

# ── KDE Plasma ────────────────────────────────────────────────────────────────
elif [ "$DE" = "KDE" ]; then
    if ! command -v kscreen-doctor >/dev/null 2>&1; then
        echo "$(date -Iseconds) [CONNECT-KDE] ERROR: kscreen-doctor not found"
        exit 0
    fi

    KDE_JSON=$(kscreen-doctor -j 2>/dev/null || echo "{}")

    # Identify the DP-3 connector name
    DP3=$(echo "$KDE_JSON" | python3 -c "
import sys, json
outputs = json.load(sys.stdin).get('outputs', [])
for o in outputs:
    n = o.get('name','')
    d = (o.get('description') or o.get('model') or '')
    if 'DP-3' in n or 'DP1080P60' in d:
        print(n); break
else:
    print('DP-3')
" 2>/dev/null || echo "DP-3")

    # Find the mode ID for 1680x1050 on DP-3
    DP3_MODE=$(echo "$KDE_JSON" | python3 -c "
import sys, json
outputs = json.load(sys.stdin).get('outputs', [])
for o in outputs:
    n = o.get('name','')
    d = (o.get('description') or o.get('model') or '')
    if 'DP-3' in n or 'DP1080P60' in d:
        for m in o.get('modes', []):
            s = m.get('size', {})
            if s.get('width') == 1680 and s.get('height') == 1050:
                print(m['id']); sys.exit(0)
print('')
" 2>/dev/null || echo "")

    echo "$(date -Iseconds) [CONNECT-KDE] Switching to DP-3 ($DP3) mode=${DP3_MODE:-5}"

    # Enable DP-3 at 1680x1050@60 (scale 1.0) and disable only actually enabled outputs atomically
    ARGS=("output.$DP3.enable")
    if [ -n "$DP3_MODE" ]; then
        ARGS+=("output.$DP3.mode.$DP3_MODE")
    else
        ARGS+=("output.$DP3.mode.1680x1050@60")
    fi
    ARGS+=("output.$DP3.position.0,0" "output.$DP3.scale.1")

    # Only disable outputs that are currently connected and enabled (excluding DP-3)
    for out_name in $(echo "$KDE_JSON" | jq -r '.outputs[] | select(.enabled == true) | .name' 2>/dev/null || true); do
        [ "$out_name" = "$DP3" ] && continue
        ARGS+=("output.$out_name.disable")
    done

    kscreen-doctor "${ARGS[@]}" || true

    # Inhibit screen lock
    qdbus6 org.freedesktop.ScreenSaver /ScreenSaver \
        org.freedesktop.ScreenSaver.Inhibit "Sunshine" "Remote session" >/dev/null 2>&1 || true

    echo "$(date -Iseconds) [CONNECT-KDE] Done."

# ── Niri ──────────────────────────────────────────────────────────────────────
elif [ "$DE" = "Niri" ]; then
    if ! command -v niri >/dev/null 2>&1; then
        echo "$(date -Iseconds) [CONNECT-NIRI] ERROR: niri not found"
        exit 0
    fi

    echo "$(date -Iseconds) [CONNECT-NIRI] Enabling DP-3 live (1680x1050@59.954, position 0 0, scale 1.0)..."
    niri msg output DP-3 on >/dev/null 2>&1 || true
    niri msg output DP-3 mode "1680x1050@59.954" >/dev/null 2>&1 || niri msg output DP-3 mode "1680x1050" >/dev/null 2>&1 || true
    niri msg output DP-3 scale 1.0 >/dev/null 2>&1 || true
    niri msg output DP-3 position set 0 0 >/dev/null 2>&1 || true

    sleep 0.2

    echo "$(date -Iseconds) [CONNECT-NIRI] Disabling local monitors (DP-1, HDMI-A-1)..."
    niri msg output DP-1 off >/dev/null 2>&1 || true
    niri msg output HDMI-A-1 off >/dev/null 2>&1 || true

    niri msg action focus-monitor DP-3 >/dev/null 2>&1 || true

    # Pause idle daemons during streaming
    pkill -STOP -x hypridle swayidle 2>/dev/null || true

    echo "$(date -Iseconds) [CONNECT-NIRI] Done."
fi

echo "$(date -Iseconds) [CONNECT] Setup complete."
exit 0
