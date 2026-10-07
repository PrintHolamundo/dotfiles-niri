#!/usr/bin/env bash
# ==============================================================================
# Script de instalación de dependencias del sistema y drivers de hardware
# Para Fedora 44 (Niri + DankMaterialShell + NVIDIA RTX 5070 + Audio + Monitores)
# ==============================================================================
set -euo pipefail

echo "=========================================================="
echo "Instalando repositorios y paquetes para Niri y hardware..."
echo "=========================================================="

# 1. Habilitar RPM Fusion (Free y Nonfree) para drivers NVIDIA y codecs
echo "[1/6] Configurando RPM Fusion..."
sudo dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# 2. Configurar repositorios externos (Brave, VS Code, Niri, DMS)
echo "[2/6] Configurando repositorios de software..."
# Brave Browser
if [ ! -f /etc/yum.repos.d/brave-browser.repo ]; then
  sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || true
fi

# Visual Studio Code
if [ ! -f /etc/yum.repos.d/vscode.repo ]; then
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc || true
  sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
fi

# Copr Repositories (Niri y DankMaterialShell)
sudo dnf copr enable -y yalter/niri || true
sudo dnf copr enable -y avengemedia/danklinux || true
sudo dnf copr enable -y avengemedia/dms || true

# 3. Instalar aplicaciones y utilidades de entorno
echo "[3/6] Instalando Niri, DankMaterialShell, Brave, VS Code, Nautilus y utilidades..."
sudo dnf install -y \
  niri \
  dms \
  dms-cli \
  danksearch \
  dankcalendar-git \
  brave-browser \
  code \
  nautilus \
  kitty \
  copyq \
  btop \
  fuzzel \
  wl-clipboard \
  grim \
  slurp \
  tesseract \
  tesseract-langpack-spa \
  tesseract-langpack-eng \
  pipewire \
  pipewire-pulseaudio \
  wireplumber \
  pciutils \
  gh \
  jq

# Symlink brave si no existe
if command -v brave-browser >/dev/null 2>&1 && ! command -v brave >/dev/null 2>&1; then
  sudo ln -sf /usr/bin/brave-browser /usr/bin/brave
fi

# 4. Instalar drivers NVIDIA propietarios para GeForce RTX 5070 (Blackwell)
echo "[4/6] Instalando drivers NVIDIA oficiales (akmod-nvidia)..."
sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda

# Compilar módulos de kernel para la GPU
echo "Compilando módulo de kernel akmod para NVIDIA..."
sudo akmods --force || true
sudo dracut --force || true

# 5. Activar servicios de usuario para DankMaterialShell
echo "[5/6] Habilitando servicios de DankMaterialShell (DMS)..."
systemctl --user enable --now dms.service 2>/dev/null || true
systemctl --user enable --now dcal.service 2>/dev/null || true

# 6. Verificación de Omnissa Horizon Client
echo "[6/6] Verificando cliente Omnissa Horizon..."
if command -v horizon-client-next >/dev/null 2>&1; then
  echo "Omnissa Horizon Client Next ya se encuentra instalado."
else
  echo "Nota: Para instalar Omnissa Horizon Client Next, descarga el instalador tarball oficial desde Omnissa Customer Connect y extrae los binarios a /usr/bin y bibliotecas a /usr/lib/omnissa."
fi

echo "=========================================================="
echo "¡Instalación de dependencias completada con éxito!"
echo "Reinicia el equipo si es la primera vez que instalas los drivers de NVIDIA."
echo "=========================================================="
