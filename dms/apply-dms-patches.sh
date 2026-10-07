#!/usr/bin/env bash
# Script para desplegar parches de batería y periféricos a DankMaterialShell

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/usr/share/quickshell/dms"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: $TARGET_DIR no existe. ¿Está instalado dms?" >&2
    exit 1
fi

echo "Aplicando parches de periféricos a DankMaterialShell..."
sudo cp "$DIR/Battery.qml" "$TARGET_DIR/Modules/DankBar/Widgets/Battery.qml"
sudo cp "$DIR/BatteryService.qml" "$TARGET_DIR/Services/BatteryService.qml"
sudo cp "$DIR/BatteryPopout.qml" "$TARGET_DIR/Modules/DankBar/Popouts/BatteryPopout.qml"

# Configurar override de systemd para DMS_SHELL_DIR
mkdir -p "$HOME/.config/systemd/user/dms.service.d"
cat << 'EOF' > "$HOME/.config/systemd/user/dms.service.d/override.conf"
[Service]
Environment="DMS_SHELL_DIR=/usr/share/quickshell/dms"
EOF

# Configurar environment.d
mkdir -p "$HOME/.config/environment.d"
if [ -f "$HOME/.config/environment.d/90-dms.conf" ]; then
    if ! grep -q "DMS_SHELL_DIR" "$HOME/.config/environment.d/90-dms.conf"; then
        echo "DMS_SHELL_DIR=/usr/share/quickshell/dms" >> "$HOME/.config/environment.d/90-dms.conf"
    fi
else
    echo "DMS_SHELL_DIR=/usr/share/quickshell/dms" > "$HOME/.config/environment.d/90-dms.conf"
fi

echo "Recargando DMS..."
systemctl --user daemon-reload
systemctl --user restart dms.service

echo "¡Parches aplicados con éxito!"
