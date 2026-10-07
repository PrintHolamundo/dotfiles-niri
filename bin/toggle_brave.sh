#!/usr/bin/env bash
# Dedicated Brave Scratchpad (exact same behavior as Super+Alt+H, but for Brave)
# Toggles special:brave, ensuring Brave is tiled inside special:brave.

set -uo pipefail

SCRATCH="brave"

active_ws() { hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' || echo 0; }
special_ws() { hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .specialWorkspace.name' || echo ""; }

# Find existing Brave browser window (excluding Gemini web app)
ADDR=$(hyprctl clients -j 2>/dev/null | jq -r '
  [ .[] | select(
    ((.class // "") == "brave-browser" or (.initialClass // "") == "brave-browser") and
    ((.class // "") | test("gemini"; "i") | not) and
    ((.initialClass // "") | test("gemini"; "i") | not)
  ) ] | sort_by(.focusHistoryID) | .[0].address // empty
')

if [ -z "$ADDR" ]; then
    # Not running yet: toggle open special:brave and launch Brave
    if [[ $(special_ws) != "special:$SCRATCH" ]]; then
        hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$SCRATCH\")" >/dev/null 2>&1
    fi
    nohup brave >/dev/null 2>&1 &
    exit 0
fi

# Ensure Brave is tiled (not floating) inside the scratchpad so it fills the screen naturally
IS_FLOAT=$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$ADDR" '.[] | select(.address == $addr) | .floating')
if [ "$IS_FLOAT" = "true" ]; then
    hyprctl dispatch "hl.dsp.window.float({ action = \"set\", window = \"address:$ADDR\", float = false })" >/dev/null 2>&1
fi

WIN_WS=$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$ADDR" '.[] | select(.address == $addr) | .workspace.name')
if [ "$WIN_WS" != "special:$SCRATCH" ]; then
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:$SCRATCH\", window = \"address:$ADDR\", silent = true })" >/dev/null 2>&1
fi

# Toggle the special workspace (exactly like ryoku-workspace scratch for Super+Alt+H)
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
    # If we just opened the scratchpad, focus Brave
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$ADDR\" })" >/dev/null 2>&1
fi
