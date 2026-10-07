#!/usr/bin/env bash
# Dedicated Kitty Terminal Scratchpad
# Supports both Niri and Hyprland:
# Shows and hides Kitty terminal (full-screen floating overlay) using Super + T
# without affecting or moving the tiled windows (mosaico).

set -uo pipefail

# ---------------------------------------------------------
# NIRI SESSION
# ---------------------------------------------------------
if [[ -n "${NIRI_SOCKET:-}" || "${XDG_CURRENT_DESKTOP:-}" == "niri" ]]; then
    SCRATCH_WS=99

    # Find existing Kitty scratchpad window in Niri
    KITTY_INFO=$(niri msg -j windows 2>/dev/null | jq -c '
      [ .[] | select(
        (.app_id // "") == "kitty-scratchpad"
      ) ] | sort_by(.focus_timestamp.secs // 0) | reverse | .[0] // empty
    ')

    if [[ -z "$KITTY_INFO" ]]; then
        (setsid kitty --class kitty-scratchpad </dev/null >/dev/null 2>&1 &)
        exit 0
    fi

    KITTY_ID=$(echo "$KITTY_INFO" | jq -r '.id')
    IS_FOCUSED=$(echo "$KITTY_INFO" | jq -r '.is_focused')
    IS_FLOATING=$(echo "$KITTY_INFO" | jq -r '.is_floating')
    KITTY_WS_ID=$(echo "$KITTY_INFO" | jq -r '.workspace_id')

    ACTIVE_WS_INFO=$(niri msg -j workspaces 2>/dev/null | jq -c '.[] | select(.is_focused == true)' | head -n1)
    if [[ -z "$ACTIVE_WS_INFO" ]]; then
        ACTIVE_WS_INFO=$(niri msg -j workspaces 2>/dev/null | jq -c '.[] | select(.is_active == true)' | head -n1)
    fi

    ACTIVE_WS_ID=$(echo "$ACTIVE_WS_INFO" | jq -r '.id')
    ACTIVE_WS_IDX=$(echo "$ACTIVE_WS_INFO" | jq -r '.idx')
    ACTIVE_OUTPUT=$(echo "$ACTIVE_WS_INFO" | jq -r '.output')
    ACTIVE_WINDOW_ID=$(echo "$ACTIVE_WS_INFO" | jq -r '.active_window_id')

    # If Kitty scratchpad is on active workspace and focused/active, hide it to scratchpad workspace
    if [[ "$KITTY_WS_ID" == "$ACTIVE_WS_ID" && ("$IS_FOCUSED" == "true" || "$ACTIVE_WINDOW_ID" == "$KITTY_ID") ]]; then
        niri msg action move-window-to-workspace --window-id "$KITTY_ID" --focus false "$SCRATCH_WS"
        exit 0
    fi

    # Otherwise, bring it to current monitor and active workspace as a FLOATING overlay
    # This ensures the underlying tiling layout (mosaico) is NOT shifted or modified at all
    niri msg action move-window-to-monitor --id "$KITTY_ID" "$ACTIVE_OUTPUT"
    niri msg action move-window-to-workspace --window-id "$KITTY_ID" --focus true "$ACTIVE_WS_IDX"

    if [[ "$IS_FLOATING" != "true" ]]; then
        niri msg action move-window-to-floating --id "$KITTY_ID" 2>/dev/null || niri msg action toggle-window-floating
    fi

    # Keep it full screen (100% width & 100% height) floating overlay over the desktop
    niri msg action set-window-width --id "$KITTY_ID" 100%
    niri msg action set-window-height --id "$KITTY_ID" 100%
    niri msg action center-window --id "$KITTY_ID"
    niri msg action focus-window --id "$KITTY_ID"
    exit 0
fi

# ---------------------------------------------------------
# HYPRLAND SESSION (Fallback)
# ---------------------------------------------------------
SCRATCH="kitty"

active_ws() { hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' || echo 0; }
special_ws() { hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .specialWorkspace.name' || echo ""; }

# Find existing Kitty scratchpad window
ADDR=$(hyprctl clients -j 2>/dev/null | jq -r '
  [ .[] | select(
    (.class // "") == "kitty-scratchpad" or (.initialClass // "") == "kitty-scratchpad"
  ) ] | sort_by(.focusHistoryID) | .[0].address // empty
')

if [ -z "$ADDR" ]; then
    nohup kitty --class kitty-scratchpad >/dev/null 2>&1 &
    sleep 0.4
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SCRATCH\")" >/dev/null 2>&1
    exit 0
fi

# Ensure window is tiled (not floating) inside the scratchpad so it fills the screen naturally
IS_FLOAT=$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$ADDR" '.[] | select(.address == $addr) | .floating')
if [ "$IS_FLOAT" = "true" ]; then
    hyprctl dispatch "hl.dsp.window.float({ action = \"set\", window = \"address:$ADDR\", float = false })" >/dev/null 2>&1
fi

WIN_WS=$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$ADDR" '.[] | select(.address == $addr) | .workspace.name')
if [ "$WIN_WS" != "special:$SCRATCH" ]; then
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:$SCRATCH\", window = \"address:$ADDR\", silent = true })" >/dev/null 2>&1
fi

# Toggle the special workspace
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
    # If we just opened the scratchpad, focus Kitty
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$ADDR\" })" >/dev/null 2>&1
fi
