#!/usr/bin/env bash

# Refrescar estado de los periféricos en segundo plano
if [ -x "$HOME/.config/quickshell/shell/services/get-peripherals" ]; then
    "$HOME/.config/quickshell/shell/services/get-peripherals" >/dev/null 2>&1
fi

CACHE_FILE="$HOME/.local/state/ryoku/peripheral_battery_cache.json"

if [ -f "$CACHE_FILE" ]; then
    MOUSE_LVL=$(jq -r '.["MX Master 3S"].level // "N/A"' "$CACHE_FILE")
    MOUSE_ST=$(jq -r '.["MX Master 3S"].status // "Desconocido"' "$CACHE_FILE")
    MOUSE_CHG=$(jq -r '.["MX Master 3S"].charging // false' "$CACHE_FILE")
    MOUSE_ON=$(jq -r '.["MX Master 3S"].online // false' "$CACHE_FILE")
    
    HEAD_LVL=$(jq -r '.["G535 Gaming Headset"].level // "N/A"' "$CACHE_FILE")
    HEAD_ST=$(jq -r '.["G535 Gaming Headset"].status // "Desconocido"' "$CACHE_FILE")
    HEAD_CHG=$(jq -r '.["G535 Gaming Headset"].charging // false' "$CACHE_FILE")
    HEAD_ON=$(jq -r '.["G535 Gaming Headset"].online // false' "$CACHE_FILE")
    
    [ "$MOUSE_CHG" = "true" ] && MOUSE_ICON="⚡ " || MOUSE_ICON=""
    [ "$HEAD_CHG" = "true" ] && HEAD_ICON="⚡ " || HEAD_ICON=""

    [ "$MOUSE_ON" = "true" ] && MOUSE_STATE="En uso" || MOUSE_STATE="$MOUSE_ST"
    [ "$HEAD_ON" = "true" ] && HEAD_STATE="En uso" || HEAD_STATE="$HEAD_ST"
    
    MSG="🖱️  MX Master 3S: ${MOUSE_ICON}${MOUSE_LVL}% (${MOUSE_STATE})
🎧  G535 Headset: ${HEAD_ICON}${HEAD_LVL}% (${HEAD_STATE})"

    KB_LVL=$(jq -r '.["K400 Plus"].level // empty' "$CACHE_FILE")
    KB_ON=$(jq -r '.["K400 Plus"].online // false' "$CACHE_FILE")
    if [ "$KB_ON" = "true" ] && [ -n "$KB_LVL" ]; then
        KB_ST=$(jq -r '.["K400 Plus"].status // "En uso"' "$CACHE_FILE")
        MSG="${MSG}
⌨️  K400 Plus: ${KB_LVL}% (${KB_ST})"
    fi
else
    MSG="No se pudo obtener información de los periféricos."
fi

notify-send "Batería de Dispositivos" "$MSG" -i battery
