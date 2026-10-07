#!/usr/bin/env bash
# Dedicated Omnissa Horizon Client Workspace Toggle
# Supports both Niri and Hyprland:
# In Niri: Horizon Client permanently resides on Workspace 2 with exact width (1625px).
# Super + Z switches to Workspace 2 to show/focus it, or returns to the previous workspace.

set -uo pipefail

# ---------------------------------------------------------
# NIRI SESSION
# ---------------------------------------------------------
if [[ -n "${NIRI_SOCKET:-}" || "${XDG_CURRENT_DESKTOP:-}" == "niri" ]]; then
    # Find existing Omnissa / Horizon Client window in Niri
    HORIZON_INFO=$(niri msg -j windows 2>/dev/null | jq -c '
      [ .[] | select(
        ((.app_id // "") | test("horizon-client|vmware-view"; "i")) or
        ((.title // "") | test("horizon|cloud desktop"; "i"))
      ) ] | sort_by(.focus_timestamp.secs // 0) | reverse | .[0] // empty
    ')

    if [[ -z "$HORIZON_INFO" ]]; then
        # Switch to Workspace 2 and launch Horizon Client
        niri msg action focus-workspace 2
        if command -v horizon-client-next >/dev/null 2>&1; then
            (setsid horizon-client-next </dev/null >/dev/null 2>&1 &)
        elif command -v horizon-client >/dev/null 2>&1; then
            (setsid horizon-client </dev/null >/dev/null 2>&1 &)
        fi
        exit 0
    fi

    HORIZON_ID=$(echo "$HORIZON_INFO" | jq -r '.id')
    HORIZON_WS=$(echo "$HORIZON_INFO" | jq -r '.workspace_id')
    IS_FOCUSED=$(echo "$HORIZON_INFO" | jq -r '.is_focused')
    IS_FLOATING=$(echo "$HORIZON_INFO" | jq -r '.is_floating')

    ACTIVE_WS_INFO=$(niri msg -j workspaces 2>/dev/null | jq -c '.[] | select(.is_focused == true)' | head -n1)
    if [[ -z "$ACTIVE_WS_INFO" ]]; then
        ACTIVE_WS_INFO=$(niri msg -j workspaces 2>/dev/null | jq -c '.[] | select(.is_active == true)' | head -n1)
    fi

    ACTIVE_WS_IDX=$(echo "$ACTIVE_WS_INFO" | jq -r '.idx')
    ACTIVE_WINDOW_ID=$(echo "$ACTIVE_WS_INFO" | jq -r '.active_window_id')

    # Ensure Horizon Client stays permanently on Workspace 2
    WS2_ID=$(niri msg -j workspaces 2>/dev/null | jq -r '.[] | select(.idx == 2) | .id')
    if [[ -n "$WS2_ID" && "$HORIZON_WS" != "$WS2_ID" ]]; then
        niri msg action move-window-to-workspace --window-id "$HORIZON_ID" 2
    fi

    # Ensure it is tiled (not floating) with the exact fixed width of 1625px
    if [[ "$IS_FLOATING" == "true" ]]; then
        niri msg action move-window-to-tiling --id "$HORIZON_ID" 2>/dev/null || niri msg action toggle-window-floating
    fi
    niri msg action set-window-width --id "$HORIZON_ID" 1625 2>/dev/null || true

    # Toggle logic:
    # If we are already on Workspace 2 and Horizon is focused/active, toggle back to previous workspace
    if [[ "$ACTIVE_WS_IDX" == "2" && ("$IS_FOCUSED" == "true" || "$ACTIVE_WINDOW_ID" == "$HORIZON_ID") ]]; then
        niri msg action focus-workspace-previous
        exit 0
    fi

    # Otherwise, switch to Workspace 2 and focus Horizon Client
    niri msg action focus-workspace 2
    niri msg action focus-window --id "$HORIZON_ID"
    exit 0
fi

# ---------------------------------------------------------
# HYPRLAND SESSION (Fallback)
# ---------------------------------------------------------
SCRATCH="omnissa"

active_ws() { hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' || echo 0; }
special_ws() { hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .specialWorkspace.name' || echo ""; }

# Find existing Omnissa window address
ADDR=$(hyprctl clients -j 2>/dev/null | jq -r '
  [ .[] | select(
    ((.class // "") | test("horizon-client|vmware-view"; "i")) or
    ((.initialClass // "") | test("horizon-client|vmware-view"; "i"))
  ) ] | sort_by(.focusHistoryID) | .[0].address // empty
')

if [ -z "$ADDR" ]; then
    # Not running yet: toggle open special:omnissa and launch Omnissa
    if [[ $(special_ws) != "special:$SCRATCH" ]]; then
        hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SCRATCH\")" >/dev/null 2>&1
    fi
    if command -v horizon-client-next >/dev/null 2>&1; then
        nohup horizon-client-next >/dev/null 2>&1 &
    elif command -v horizon-client >/dev/null 2>&1; then
        nohup horizon-client >/dev/null 2>&1 &
    fi
    exit 0
fi

# Ensure Omnissa is floating, sized and placed as configured
IS_FLOAT=$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$ADDR" '.[] | select(.address == $addr) | .floating')
if [ "$IS_FLOAT" != "true" ]; then
    hyprctl dispatch "hl.dsp.window.float({ action = \"set\", window = \"address:$ADDR\", float = true })" >/dev/null 2>&1
fi
hyprctl dispatch "hl.dsp.window.resize({ x = 1920, y = 1066, exact = true, window = \"address:$ADDR\" })" >/dev/null 2>&1
hyprctl dispatch "movewindowpixel exact 54 7,address:$ADDR" >/dev/null 2>&1 || true

WIN_WS=$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$ADDR" '.[] | select(.address == $addr) | .workspace.name')
if [ "$WIN_WS" != "special:$SCRATCH" ]; then
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:$SCRATCH\", window = \"address:$ADDR\", silent = true })" >/dev/null 2>&1
fi

# Toggle the special workspace (exactly like toggle_brave.sh for Super+B)
back=$(active_ws)
hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SCRATCH\")" >/dev/null 2>&1

# If we just hid the scratchpad, restore keyboard focus to the visible window on screen
if [[ -z $(special_ws) && $back -ge 1 ]]; then
    addr=$(hyprctl clients -j 2>/dev/null | jq -r --argjson ws "$back" \
        'map(select(.workspace.id == $ws)) | sort_by(.focusHistoryID) | .[0].address // empty' \
        || true)
    [[ -n $addr ]] &&
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null 2>&1
else
    # If we just opened the scratchpad, focus Omnissa
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$ADDR\" })" >/dev/null 2>&1
fi
