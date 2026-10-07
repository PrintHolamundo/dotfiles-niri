#!/usr/bin/env bash
set -euo pipefail

LOG="$HOME/.local/share/sunshine-macbook.log"
mkdir -p "$(dirname "$LOG")"

command -v kscreen-doctor >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Clean stale locks
rm -f /tmp/sunshine_streaming.lock

ACTIVE_OUTPUTS=$(kscreen-doctor -j 2>/dev/null || echo "{}")

# Check if DP-1 exists
DP1_ENABLED=$(echo "$ACTIVE_OUTPUTS" | jq -r '.outputs[] | select(.name == "DP-1") | .enabled' 2>/dev/null || echo "not_found")
DP3_NAME=$(echo "$ACTIVE_OUTPUTS" | jq -r '.outputs[] | select((.name | test("(?i)DP-?3")) or ((.description // "") | test("(?i)DP1080P60"))) | .name' 2>/dev/null | head -n1 || echo "DP-3")

echo "$(date -Iseconds) [BOOT-CHECK-KDE] KDE started. DP-1 enabled: $DP1_ENABLED" >> "$LOG"

if [ "$DP1_ENABLED" = "false" ] || [ "$DP1_ENABLED" = "true" ]; then
    # DP-1 is physically detected.
    if [ "$DP1_ENABLED" = "false" ]; then
        echo "$(date -Iseconds) [BOOT-CHECK-KDE] DP-1 was left disabled. Re-enabling DP-1, disabling $DP3_NAME..." >> "$LOG"
        DP1_MODE=$(echo "$ACTIVE_OUTPUTS" | jq -r '.outputs[] | select(.name == "DP-1") | .modes[] | select(.size.width == 3440 and .size.height == 1440) | .id' 2>/dev/null | head -n1 || echo "")
        K_ARGS=("output.DP-1.enable")
        if [ -n "$DP1_MODE" ]; then
            K_ARGS+=("output.DP-1.mode.$DP1_MODE")
        else
            K_ARGS+=("output.DP-1.mode.3440x1440@144")
        fi
        K_ARGS+=("output.DP-1.scale.1.6" "output.DP-1.position.0,0" "output.$DP3_NAME.disable")
        kscreen-doctor "${K_ARGS[@]}" >> "$LOG" 2>&1 || true
    else
        # Ensure DP-3 is disabled
        kscreen-doctor "output.$DP3_NAME.disable" >> "$LOG" 2>&1 || true
    fi
else
    # Pure headless boot in KDE: enable DP-3 at 1680x1050@60
    echo "$(date -Iseconds) [BOOT-CHECK-KDE] DP-1 not detected (headless boot). Enabling $DP3_NAME at 1680x1050@60..." >> "$LOG"
    kscreen-doctor "output.$DP3_NAME.enable" "output.$DP3_NAME.mode.1680x1050@60" "output.$DP3_NAME.scale.1" "output.$DP3_NAME.position.0,0" >> "$LOG" 2>&1 || true
fi

exit 0
