#!/usr/bin/env bash
# Dedicated System Monitor Scratchpad (btop)
# Supports both Niri and Hyprland:
# Shows and hides btop (CPU, RAM, GPU, Disks, Network, Processes) as a floating overlay using Super + Esc
# without affecting or moving the tiled windows (mosaico).

set -uo pipefail

# ---------------------------------------------------------
# NIRI SESSION
# ---------------------------------------------------------
if [[ -n "${NIRI_SOCKET:-}" || "${XDG_CURRENT_DESKTOP:-}" == "niri" ]]; then
    SCRATCH_WS=99

    # Find existing btop window in Niri
    BTOP_INFO=$(niri msg -j windows 2>/dev/null | jq -c '
      [ .[] | select(
        (.app_id // "") == "btop-system"
      ) ] | sort_by(.focus_timestamp.secs // 0) | reverse | .[0] // empty
    ')

    if [[ -z "$BTOP_INFO" ]]; then
        (setsid kitty --class btop-system -T "Monitor del Sistema" -e btop </dev/null >/dev/null 2>&1 &)
        exit 0
    fi

    BTOP_ID=$(echo "$BTOP_INFO" | jq -r '.id')
    IS_FOCUSED=$(echo "$BTOP_INFO" | jq -r '.is_focused')
    IS_FLOATING=$(echo "$BTOP_INFO" | jq -r '.is_floating')
    BTOP_WS_ID=$(echo "$BTOP_INFO" | jq -r '.workspace_id')

    ACTIVE_WS_INFO=$(niri msg -j workspaces 2>/dev/null | jq -c '.[] | select(.is_focused == true)' | head -n1)
    if [[ -z "$ACTIVE_WS_INFO" ]]; then
        ACTIVE_WS_INFO=$(niri msg -j workspaces 2>/dev/null | jq -c '.[] | select(.is_active == true)' | head -n1)
    fi

    ACTIVE_WS_ID=$(echo "$ACTIVE_WS_INFO" | jq -r '.id')
    ACTIVE_WS_IDX=$(echo "$ACTIVE_WS_INFO" | jq -r '.idx')
    ACTIVE_OUTPUT=$(echo "$ACTIVE_WS_INFO" | jq -r '.output')
    ACTIVE_WINDOW_ID=$(echo "$ACTIVE_WS_INFO" | jq -r '.active_window_id')

    # If btop is on active workspace and focused/active, hide it to scratchpad workspace
    if [[ "$BTOP_WS_ID" == "$ACTIVE_WS_ID" && ("$IS_FOCUSED" == "true" || "$ACTIVE_WINDOW_ID" == "$BTOP_ID") ]]; then
        niri msg action move-window-to-workspace --window-id "$BTOP_ID" --focus false "$SCRATCH_WS"
        exit 0
    fi

    # Otherwise, bring it to current monitor and active workspace as a FLOATING overlay
    # This ensures the underlying tiling layout (mosaico) is NOT shifted or modified at all
    niri msg action move-window-to-monitor --id "$BTOP_ID" "$ACTIVE_OUTPUT"
    niri msg action move-window-to-workspace --window-id "$BTOP_ID" --focus true "$ACTIVE_WS_IDX"

    if [[ "$IS_FLOATING" != "true" ]]; then
        niri msg action move-window-to-floating --id "$BTOP_ID" 2>/dev/null || niri msg action toggle-window-floating
    fi

    # Center floating overlay at 85% width and 85% height
    niri msg action set-window-width --id "$BTOP_ID" 85%
    niri msg action set-window-height --id "$BTOP_ID" 85%
    niri msg action center-window --id "$BTOP_ID"
    niri msg action focus-window --id "$BTOP_ID"
    exit 0
fi

# ---------------------------------------------------------
# HYPRLAND SESSION (Fallback)
# ---------------------------------------------------------
SCRATCH="btop"

active_ws() { hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' || echo 0; }
special_ws() { hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .specialWorkspace.name' || echo ""; }

# Find existing btop window in Hyprland
ADDR=$(hyprctl clients -j 2>/dev/null | jq -r '
  [ .[] | select(
    (.class // "") == "btop-system" or (.initialClass // "") == "btop-system"
  ) ] | sort_by(.focusHistoryID) | .[0].address // empty
')

if [ -z "$ADDR" ]; then
    nohup kitty --class btop-system -T "Monitor del Sistema" -e btop >/dev/null 2>&1 &
    sleep 0.4
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SCRATCH\")" >/dev/null 2>&1
    exit 0
fi

IS_FLOAT=$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$ADDR" '.[] | select(.address == $addr) | .floating')
if [ "$IS_FLOAT" != "true" ]; then
    hyprctl dispatch "hl.dsp.window.float({ action = \"set\", window = \"address:$ADDR\", float = true })" >/dev/null 2>&1
    hyprctl dispatch "hl.dsp.window.resize({ x = 1600, y = 950, exact = true, window = \"address:$ADDR\" })" >/dev/null 2>&1
    hyprctl dispatch "hl.dsp.window.center({ window = \"address:$ADDR\" })" >/dev/null 2>&1
fi

WIN_WS=$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$ADDR" '.[] | select(.address == $addr) | .workspace.name')
if [ "$WIN_WS" != "special:$SCRATCH" ]; then
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:$SCRATCH\", window = \"address:$ADDR\", silent = true })" >/dev/null 2>&1
fi

# Toggle the special workspace
back=$(active_ws)
hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SCRATCH\")" >/dev/null 2>&1

if [[ -z $(special_ws) && $back -ge 1 ]]; then
    addr=$(hyprctl clients -j 2>/dev/null | jq -r --argjson ws "$back" \
        'map(select(.workspace.id == $ws)) | sort_by(.focusHistoryID) | .[0].address // empty' \
        || true)
    [[ -n $addr ]] &&
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null 2>&1
else
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$ADDR\" })" >/dev/null 2>&1
fi
