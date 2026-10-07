#!/usr/bin/env bash
# Script para iniciar aplicaciones que requieren conexión a internet activa

# Esperar a que NetworkManager confirme conexión (hasta 20 segundos)
if command -v nm-online >/dev/null 2>&1; then
    nm-online -q --timeout=20 || true
fi

# Fallback rápido: verificar conectividad real por ping
for i in {1..20}; do
    if ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

# Breve pausa para estabilización de rutas y DNS
sleep 1

# Iniciar aplicaciones que requieren internet
brave &
horizon-client-next &
