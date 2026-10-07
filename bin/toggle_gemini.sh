#!/usr/bin/env bash
# Dedicated Gemini Scratchpad
# Supports both Niri and Hyprland:
# Shows and hides Gemini web app as a floating, expanded overlay using Super + G
# without affecting or moving the tiled windows (mosaico).

set -uo pipefail

APP_URL="https://gemini.google.com"

# ---------------------------------------------------------
# NIRI SESSION
# ---------------------------------------------------------
if [[ -n "${NIRI_SOCKET:-}" || "${XDG_CURRENT_DESKTOP:-}" == "niri" ]]; then
    SCRATCH_WS=99

    # Find existing Gemini window in Niri
    GEMINI_INFO=$(niri msg -j windows 2>/dev/null | jq -c '
      [ .[] | select(
        ((.app_id // "") | test("gemini"; "i")) or
        ((.title // "") | test("gemini"; "i") and ((.app_id // "") | test("brave"; "i")))
      ) ] | sort_by(.focus_timestamp.secs // 0) | reverse | .[0] // empty
    ')

    if [[ -z "$GEMINI_INFO" ]]; then
        nohup brave --app="$APP_URL" >/dev/null 2>&1 &
        exit 0
    fi

    GEMINI_ID=$(echo "$GEMINI_INFO" | jq -r '.id')
    IS_FOCUSED=$(echo "$GEMINI_INFO" | jq -r '.is_focused')
    IS_FLOATING=$(echo "$GEMINI_INFO" | jq -r '.is_floating')
    GEMINI_WS_ID=$(echo "$GEMINI_INFO" | jq -r '.workspace_id')

    ACTIVE_WS_INFO=$(niri msg -j workspaces 2>/dev/null | jq -c '.[] | select(.is_focused == true)' | head -n1)
    if [[ -z "$ACTIVE_WS_INFO" ]]; then
        ACTIVE_WS_INFO=$(niri msg -j workspaces 2>/dev/null | jq -c '.[] | select(.is_active == true)' | head -n1)
    fi

    ACTIVE_WS_ID=$(echo "$ACTIVE_WS_INFO" | jq -r '.id')
    ACTIVE_WS_IDX=$(echo "$ACTIVE_WS_INFO" | jq -r '.idx')
    ACTIVE_OUTPUT=$(echo "$ACTIVE_WS_INFO" | jq -r '.output')
    ACTIVE_WINDOW_ID=$(echo "$ACTIVE_WS_INFO" | jq -r '.active_window_id')

    # If Gemini is on the active workspace and is focused/active, hide it to the scratchpad workspace
    if [[ "$GEMINI_WS_ID" == "$ACTIVE_WS_ID" && ("$IS_FOCUSED" == "true" || "$ACTIVE_WINDOW_ID" == "$GEMINI_ID") ]]; then
        niri msg action move-window-to-workspace --window-id "$GEMINI_ID" --focus false "$SCRATCH_WS"
        exit 0
    fi

    # Otherwise, bring it to the current monitor and active workspace as a FLOATING overlay
    # This ensures the underlying tiling layout (mosaico) is NOT shifted or modified at all
    niri msg action move-window-to-monitor --id "$GEMINI_ID" "$ACTIVE_OUTPUT"
    niri msg action move-window-to-workspace --window-id "$GEMINI_ID" --focus true "$ACTIVE_WS_IDX"

    if [[ "$IS_FLOATING" != "true" ]]; then
        niri msg action move-window-to-floating --id "$GEMINI_ID" 2>/dev/null || niri msg action toggle-window-floating
    fi

    # Keep it full screen (100% width & 100% height) floating overlay over the desktop
    niri msg action set-window-width --id "$GEMINI_ID" 100%
    niri msg action set-window-height --id "$GEMINI_ID" 100%
    niri msg action center-window --id "$GEMINI_ID"
    niri msg action focus-window --id "$GEMINI_ID"
    exit 0
fi

# ---------------------------------------------------------
# HYPRLAND SESSION (Fallback)
# ---------------------------------------------------------
SCRATCH="gemini"

active_ws() { hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' || echo 0; }
special_ws() { hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .specialWorkspace.name' || echo ""; }

# Robust search for Gemini window address
ADDR=$(hyprctl clients -j 2>/dev/null | jq -r '
  [ .[] | select(
    ((.initialClass // "") | test("gemini"; "i")) or
    ((.class // "") | test("gemini"; "i")) or
    (((.title // "") | test("gemini"; "i")) and ((.class // "") | test("brave"; "i")))
  ) ] | sort_by(.focusHistoryID) | .[0].address // empty
')

if [ -z "$ADDR" ]; then
    # Not running yet: toggle open special:gemini and launch Gemini
    if [[ $(special_ws) != "special:$SCRATCH" ]]; then
        hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SCRATCH\")" >/dev/null 2>&1
    fi
    nohup brave --app="$APP_URL" >/dev/null 2>&1 &
    exit 0
fi

# Ensure Gemini is floating and centered
IS_FLOAT=$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$ADDR" '.[] | select(.address == $addr) | .floating')
if [ "$IS_FLOAT" != "true" ]; then
    hyprctl dispatch "hl.dsp.window.float({ action = \"set\", window = \"address:$ADDR\", float = true })" >/dev/null 2>&1
    hyprctl dispatch "hl.dsp.window.resize({ x = 1050, y = 750, exact = true, window = \"address:$ADDR\" })" >/dev/null 2>&1
    hyprctl dispatch "hl.dsp.window.center({ window = \"address:$ADDR\" })" >/dev/null 2>&1
fi

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
    # If we just opened the scratchpad, focus Gemini
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$ADDR\" })" >/dev/null 2>&1
fi
