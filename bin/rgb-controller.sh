#!/usr/bin/env bash

ACTION="${1:-auto}"

turn_off() {
    openrgb -c 000000 >/dev/null 2>&1
}

turn_on() {
    if [ -f "$HOME/.config/OpenRGB/profiles/lights_on.json" ]; then
        openrgb --profile lights_on >/dev/null 2>&1
    else
        openrgb -d "ENE DRAM" -m Rainbow -d "HyperX Fury RGB" -m Rainbow -d "B460M AORUS ELITE" -m "Color Cycle" >/dev/null 2>&1 || openrgb -c 00FFCC >/dev/null 2>&1
    fi
}

case "$ACTION" in
    off)
        turn_off
        ;;
    on)
        turn_on
        ;;
    auto)
        CURRENT_HOUR=$(date +%-H)
        # Horario nocturno: 12:00 AM (00:00) hasta las 06:59:59 AM
        if [ "$CURRENT_HOUR" -ge 0 ] && [ "$CURRENT_HOUR" -lt 7 ]; then
            turn_off
        else
            turn_on
        fi
        ;;
    *)
        echo "Uso: $0 {on|off|auto}"
        exit 1
        ;;
esac
