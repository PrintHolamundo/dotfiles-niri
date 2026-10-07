#!/usr/bin/env bash
set -e

# Robust environment setup
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${UID:-1000}}"

if [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
    for sock in $(find "$XDG_RUNTIME_DIR/hypr" -maxdepth 2 -name ".socket.sock" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk '{print $2}'); do
        sig=$(basename "$(dirname "$sock")")
        if hyprctl -i "$sig" version >/dev/null 2>&1; then
            export HYPRLAND_INSTANCE_SIGNATURE="$sig"
            break
        fi
    done
fi

if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    WL=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name "wayland-*" ! -name "*.lock" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | awk '{print $2}' | xargs -r basename || true)
    [ -n "$WL" ] && export WAYLAND_DISPLAY="$WL"
fi

if [ -z "${NIRI_SOCKET:-}" ]; then
    NS=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name "niri.*.sock" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | awk '{print $2}')
    [ -n "$NS" ] && export NIRI_SOCKET="$NS"
fi

# Detect Desktop Environment
DE="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
if [[ -z "$DE" ]] || [[ "$DE" =~ [Uu]nknown ]]; then
    if pgrep -x Hyprland >/dev/null 2>&1; then
        DE="Hyprland"
    elif pgrep -x kwin_wayland >/dev/null 2>&1; then
        DE="KDE"
    elif pgrep -x niri >/dev/null 2>&1; then
        DE="Niri"
    fi
fi

EXTRA_ARGS=()

if [[ "$DE" =~ [Kk][Dd][Ee] ]] || [[ "$DE" =~ [Pp]lasma ]]; then
    EXTRA_ARGS+=("output_name=DP-3")
elif [[ "$DE" =~ [Hh]yprland ]]; then
    EXTRA_ARGS+=("output_name=DP-3")
elif [[ "$DE" =~ [Nn]iri ]]; then
    EXTRA_ARGS+=("output_name=DP-3")
fi

# Ensure there is at least one active output for Sunshine to probe encoders
ensure_display_ready() {
    if [[ "$DE" =~ [Hh]yprland ]]; then
        if command -v hyprctl >/dev/null 2>&1; then
            if ! hyprctl monitors -j 2>/dev/null | python3 -c "import sys,json; sys.exit(0 if any(m.get('name')=='DP-1' and not m.get('disabled',False) for m in json.load(sys.stdin)) else 1)" 2>/dev/null; then
                echo "$(date -Iseconds) [WRAPPER] DP-1 not active in Hyprland. Ensuring DP-3 enabled for Sunshine..."
                hyprctl eval 'hl.monitor({ output = "DP-3", mode = "1680x1050@59.95", position = "0x0", scale = 1, disabled = false })' >/dev/null 2>&1 || true
            fi
        fi
    elif [[ "$DE" =~ [Nn]iri ]]; then
        if command -v niri >/dev/null 2>&1; then
            if ! niri msg -j outputs 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('DP-1',{}).get('logical') is not None else 1)" 2>/dev/null; then
                echo "$(date -Iseconds) [WRAPPER] DP-1 not active in Niri. Ensuring DP-3 enabled for Sunshine..."
                niri msg output DP-3 on >/dev/null 2>&1 || true
                niri msg output DP-3 mode "1680x1050@59.954" >/dev/null 2>&1 || true
                niri msg output DP-3 scale 1.0 >/dev/null 2>&1 || true
                niri msg output DP-3 position set 0 0 >/dev/null 2>&1 || true
            fi
        fi
    elif [[ "$DE" =~ [Kk][Dd][Ee] ]] || [[ "$DE" =~ [Pp]lasma ]]; then
        if command -v kscreen-doctor >/dev/null 2>&1; then
            if ! kscreen-doctor -j 2>/dev/null | jq -e '.outputs[] | select(.name == "DP-1" and .enabled == true)' >/dev/null 2>&1; then
                echo "$(date -Iseconds) [WRAPPER] DP-1 not active in KDE. Ensuring DP-3 enabled for Sunshine..."
                kscreen-doctor "output.DP-3.enable" "output.DP-3.mode.1680x1050@60" "output.DP-3.scale.1" "output.DP-3.position.0,0" >/dev/null 2>&1 || true
            fi
        fi
    fi
}
ensure_display_ready || true

exec /usr/bin/sunshine "$HOME/.config/sunshine/sunshine.conf" "${EXTRA_ARGS[@]}" "$@"
