#!/usr/bin/env bash
# sunshine_macbook_disconnect.sh
# Called by Sunshine when a client disconnects.
# Action:
#   Hyprland: enable DP-1 at 3440x1440@144 scale 1.6 at 0x0, migrate workspaces, disable DP-3 & HDMI-A-1
#   KDE:      enable DP-1 at 3440x1440@144 scale 1.6, disable other outputs atomically
#   Niri:     enable DP-1 at 3440x1440@144 scale 1.25, disable DP-3
set -euo pipefail

LOG="$HOME/.local/share/sunshine-macbook.log"
mkdir -p "$(dirname "$LOG")"
exec >> "$LOG" 2>&1

# Concurrency lock: serialize rapid connect/disconnect events cleanly
exec 200>/tmp/sunshine_macbook_switch.lock
flock -w 10 200 || { echo "$(date -Iseconds) [DISCONNECT] Lock timeout; continuing anyway"; }

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
echo "$(date -Iseconds) [DISCONNECT] Client disconnected (DE=$DE)"

# ── Hyprland ──────────────────────────────────────────────────────────────────
if [ "$DE" = "Hyprland" ]; then
    if ! command -v hyprctl >/dev/null 2>&1; then
        echo "$(date -Iseconds) [DISCONNECT-HYPR] ERROR: hyprctl not found"
    else
        MON_USER="$HOME/.config/hypr/monitors_user.lua"

        echo "$(date -Iseconds) [DISCONNECT-HYPR] Enabling DP-1 live (3440x1440@144.00, position 0x0, scale 1.3333333)..."
        hyprctl eval 'hl.monitor({ output = "DP-1", mode = "3440x1440@144.00", position = "0x0", scale = 1.3333333, disabled = false })' >/dev/null 2>&1 || true

        # Wait up to 2 seconds for DP-1 to be confirmed active
        DP1_ACTIVE=false
        for i in $(seq 1 20); do
            if hyprctl monitors -j 2>/dev/null \
               | python3 -c "import sys,json; sys.exit(0 if any(m.get('name')=='DP-1' and not m.get('disabled',False) for m in json.load(sys.stdin)) else 1)" \
               2>/dev/null; then
                DP1_ACTIVE=true
                echo "$(date -Iseconds) [DISCONNECT-HYPR] DP-1 active ✓"
                break
            fi
            sleep 0.1
        done

        if [ "$DP1_ACTIVE" = "true" ]; then
            echo "$(date -Iseconds) [DISCONNECT-HYPR] Migrating workspaces back to DP-1..."
            for ws in $(hyprctl workspaces -j 2>/dev/null | jq -r '.[].id' 2>/dev/null || true); do
                [ -z "$ws" ] && continue
                hyprctl dispatch "hl.dsp.workspace.move({ workspace = $ws, monitor = \"DP-1\" })" >/dev/null 2>&1 || true
            done

            ACTIVE_WS=$(cat "$HOME/.local/state/sunshine_active_ws.txt" 2>/dev/null || echo "1")
            hyprctl dispatch "hl.dsp.focus({ workspace = $ACTIVE_WS })" >/dev/null 2>&1 || true
            rm -f "$HOME/.local/state/sunshine_active_ws.txt"

            hyprctl dispatch focusmonitor DP-1 >/dev/null 2>&1 || true

            echo "$(date -Iseconds) [DISCONNECT-HYPR] Disabling remote dummy monitor (DP-3) and HDMI-A-1..."
            hyprctl eval 'hl.monitor({ output = "DP-3", mode = "1680x1050@59.95", position = "3440x0", scale = 1, disabled = true })' >/dev/null 2>&1 || true
            hyprctl eval 'hl.monitor({ output = "HDMI-A-1", disabled = true })' >/dev/null 2>&1 || true

            cat > "$MON_USER" << 'LUA'
-- sunshine local override (disconnect)
hl.monitor({ output = "DP-1",    mode = "3440x1440@144.00", position = "0x0", scale = 1.3333333, disabled = false })
hl.monitor({ output = "HDMI-A-1", disabled = true })
hl.monitor({ output = "DP-3",    mode = "1680x1050@59.95", position = "3440x0", scale = 1, disabled = true })
LUA
        else
            echo "$(date -Iseconds) [DISCONNECT-HYPR] DP-1 is OFF/disconnected. Keeping DP-3 ACTIVE so Sunshine stays ready."
            hyprctl eval 'hl.monitor({ output = "DP-3", mode = "1680x1050@59.95", position = "0x0", scale = 1, disabled = false })' >/dev/null 2>&1 || true
            hyprctl dispatch focusmonitor DP-3 >/dev/null 2>&1 || true
            cat > "$MON_USER" << 'LUA'
-- sunshine headless override (disconnect with DP-1 off)
hl.monitor({ output = "DP-1",    disabled = true })
hl.monitor({ output = "HDMI-A-1", disabled = true })
hl.monitor({ output = "DP-3",    mode = "1680x1050@59.95", position = "0x0", scale = 1, disabled = false })
LUA
        fi

        # Restore hardware cursor
        hyprctl eval "hl.config({ cursor = { no_hardware_cursors = 2 } })" >/dev/null 2>&1 || true

        # Resume hypridle daemon
        pkill -CONT -x hypridle 2>/dev/null || true

        # Clean up stale virtual outputs only if they exist
        if hyprctl monitors all -j 2>/dev/null | jq -e '.[] | select(.name == "HEADLESS-1")' >/dev/null 2>&1; then
            hyprctl output remove HEADLESS-1 >/dev/null 2>&1 || true
        fi

        echo "$(date -Iseconds) [DISCONNECT-HYPR] Done."
        (sleep 1 && command -v ryoku-cmd-nightlight >/dev/null 2>&1 && ryoku-cmd-nightlight restore) &
    fi

# ── KDE Plasma ────────────────────────────────────────────────────────────────
elif [ "$DE" = "KDE" ]; then
    if ! command -v kscreen-doctor >/dev/null 2>&1; then
        echo "$(date -Iseconds) [DISCONNECT-KDE] ERROR: kscreen-doctor not found"
    else
        KDE_JSON=$(kscreen-doctor -j 2>/dev/null || echo "{}")

        # Check if DP-1 is physically detected
        DP1_EXISTS=$(echo "$KDE_JSON" | jq -r '.outputs[] | select(.name == "DP-1") | .name' 2>/dev/null || echo "")

        if [ -n "$DP1_EXISTS" ]; then
            DP1_MODE=$(echo "$KDE_JSON" | python3 -c "
import sys, json
outputs = json.load(sys.stdin).get('outputs', [])
for o in outputs:
    if o.get('name') == 'DP-1':
        m_list = [m for m in o.get('modes', []) if m.get('size', {}).get('width') == 3440 and m.get('size', {}).get('height') == 1440]
        m_list.sort(key=lambda m: m.get('refreshRate', 0), reverse=True)
        if m_list:
            print(m_list[0]['id']); sys.exit(0)
print('')
" 2>/dev/null || echo "")

            K_ARGS=("output.DP-1.enable")
            if [ -n "$DP1_MODE" ]; then
                K_ARGS+=("output.DP-1.mode.$DP1_MODE")
            else
                K_ARGS+=("output.DP-1.mode.3440x1440@144.00")
            fi
            K_ARGS+=("output.DP-1.scale.1.6" "output.DP-1.position.0,0")

            for out_name in $(echo "$KDE_JSON" | jq -r '.outputs[] | select(.enabled == true and .name != "DP-1") | .name' 2>/dev/null || true); do
                K_ARGS+=("output.$out_name.disable")
            done

            kscreen-doctor "${K_ARGS[@]}" || true
            echo "$(date -Iseconds) [DISCONNECT-KDE] Done (DP-1 enabled)."
        else
            echo "$(date -Iseconds) [DISCONNECT-KDE] DP-1 not detected. Keeping DP-3 enabled."
        fi
    fi

# ── Niri ──────────────────────────────────────────────────────────────────────
elif [ "$DE" = "Niri" ]; then
    if ! command -v niri >/dev/null 2>&1; then
        echo "$(date -Iseconds) [DISCONNECT-NIRI] ERROR: niri not found"
    else
        echo "$(date -Iseconds) [DISCONNECT-NIRI] Enabling DP-1 live (3440x1440@144.000, position 0 0, scale 1.25)..."
        niri msg output DP-1 on >/dev/null 2>&1 || true
        niri msg output DP-1 mode "3440x1440@144.000" >/dev/null 2>&1 || true
        niri msg output DP-1 scale 1.25 >/dev/null 2>&1 || true
        niri msg output DP-1 position set 0 0 >/dev/null 2>&1 || true

        sleep 0.5

        # Check if DP-1 actually became active
        DP1_ACTIVE=false
        if niri msg -j outputs 2>/dev/null | python3 -c "
import sys, json
try:
    outputs = json.load(sys.stdin)
    dp1 = outputs.get('DP-1')
    if dp1 and dp1.get('logical') is not None:
        sys.exit(0)
except Exception:
    pass
sys.exit(1)
"; then
            DP1_ACTIVE=true
        fi

        if [ "$DP1_ACTIVE" = "true" ]; then
            echo "$(date -Iseconds) [DISCONNECT-NIRI] DP-1 active ✓. Disabling remote dummy monitor (DP-3)..."
            niri msg action focus-monitor DP-1 >/dev/null 2>&1 || true
            niri msg output DP-3 off >/dev/null 2>&1 || true
        else
            echo "$(date -Iseconds) [DISCONNECT-NIRI] DP-1 is OFF/disconnected. Keeping DP-3 ACTIVE so Sunshine stays ready."
            niri msg output DP-3 on >/dev/null 2>&1 || true
            niri msg output DP-3 mode "1680x1050@59.954" >/dev/null 2>&1 || true
            niri msg output DP-3 scale 1.0 >/dev/null 2>&1 || true
            niri msg output DP-3 position set 0 0 >/dev/null 2>&1 || true
            niri msg action focus-monitor DP-3 >/dev/null 2>&1 || true
        fi

        # Resume idle daemons
        pkill -CONT -x hypridle swayidle 2>/dev/null || true

        echo "$(date -Iseconds) [DISCONNECT-NIRI] Done."
    fi
fi

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -f /tmp/sunshine_streaming.lock
echo "$(date -Iseconds) [DISCONNECT] Complete."
exit 0
