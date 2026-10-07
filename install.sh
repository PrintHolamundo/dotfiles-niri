#!/usr/bin/env bash
# ==============================================================================
# Dotfiles Installer for Niri & Custom Scripts
# Compatible with Arch Linux, Fedora, Ubuntu/Debian, openSUSE, etc.
# ==============================================================================

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
INSTALL_MODE="symlink" # default: symlink (or "copy")
INSTALL_PKGS=false
ASSUME_YES=false

# Colors
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[34m"
C_RED="\033[31m"

info()    { echo -e "${C_BLUE}${C_BOLD}[INFO]${C_RESET} $*"; }
success() { echo -e "${C_GREEN}${C_BOLD}[OK]${C_RESET} $*"; }
warn()    { echo -e "${C_YELLOW}${C_BOLD}[WARN]${C_RESET} $*"; }
error()   { echo -e "${C_RED}${C_BOLD}[ERROR]${C_RESET} $*"; }

usage() {
    cat << EOF
Uso: $0 [opciones]

Opciones:
  -s, --symlink     Crea enlaces simbólicos (Recomendado para dotfiles con Git) [Por defecto]
  -c, --copy        Copia los archivos directamente en lugar de enlazar
  -p, --packages    Intenta instalar paquetes y dependencias del sistema automáticamente
  -y, --yes         Modo desatendido (no solicita confirmación)
  -h, --help        Muestra esta ayuda

EOF
    exit 0
}

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--symlink)   INSTALL_MODE="symlink"; shift ;;
        -c|--copy)      INSTALL_MODE="copy"; shift ;;
        -p|--packages)  INSTALL_PKGS=true; shift ;;
        -y|--yes)       ASSUME_YES=true; shift ;;
        -h|--help)      usage ;;
        *)              error "Opción desconocida: $1"; usage ;;
    esac
done

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_LIKE="${ID_LIKE:-}"
    else
        DISTRO_ID="unknown"
        DISTRO_LIKE=""
    fi
}

install_packages() {
    detect_distro
    info "Distribución detectada: $DISTRO_ID ($DISTRO_LIKE)"

    if [[ "$DISTRO_ID" == "arch" || "$DISTRO_LIKE" =~ arch ]]; then
        info "Detectado Arch Linux / Arch-based. Verificando gestor AUR..."
        local aur_helper=""
        if command -v paru >/dev/null 2>&1; then
            aur_helper="paru"
        elif command -v yay >/dev/null 2>&1; then
            aur_helper="yay"
        fi

        local pkgs=(
            niri
            kitty
            copyq
            jq
            wl-clipboard
            grim
            slurp
            tesseract
            tesseract-data-eng
            tesseract-data-spa
            libnotify
            pipewire
            pipewire-pulse
            wireplumber
            btop
            python
        )

        if [ -n "$aur_helper" ]; then
            info "Instalando paquetes con $aur_helper..."
            $aur_helper -S --needed "${pkgs[@]}"
        else
            warn "No se encontró paru/yay. Instalando vía pacman (requiere sudo):"
            sudo pacman -S --needed "${pkgs[@]}"
        fi

    elif [[ "$DISTRO_ID" == "fedora" || "$DISTRO_LIKE" =~ fedora ]]; then
        info "Detectado Fedora. Verificando dependencias..."
        local pkgs=(
            kitty
            copyq
            jq
            wl-clipboard
            grim
            slurp
            tesseract
            libnotify
            pipewire-pulseaudio
            wireplumber
            btop
            python3
        )
        sudo dnf install -y "${pkgs[@]}"
        if ! command -v niri >/dev/null 2>&1; then
            warn "Niri no está instalado. En Fedora puedes habilitar el copr: sudo dnf copr enable yalter/niri && sudo dnf install niri"
        fi

    elif [[ "$DISTRO_ID" =~ debian|ubuntu || "$DISTRO_LIKE" =~ debian|ubuntu ]]; then
        info "Detectado Debian/Ubuntu. Instalando paquetes base..."
        sudo apt update
        local pkgs=(
            kitty
            copyq
            jq
            wl-clipboard
            grim
            slurp
            tesseract-ocr
            libnotify-bin
            pulseaudio-utils
            btop
            python3
        )
        sudo apt install -y "${pkgs[@]}"
        if ! command -v niri >/dev/null 2>&1; then
            warn "Niri debe instalarse compilado o mediante su repositorio/PPA oficial."
        fi
    else
        warn "Distribución no soportada automáticamente para instalación de paquetes."
        warn "Asegúrate de tener instalados: niri, kitty, jq, wl-clipboard, grim, slurp, tesseract, libnotify, btop, python3."
    fi
}

backup_item() {
    local target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        mkdir -p "$BACKUP_DIR"
        local rel_path="${target#$HOME/}"
        local dest="$BACKUP_DIR/$rel_path"
        mkdir -p "$(dirname "$dest")"
        mv "$target" "$dest"
        info "Respaldado previo: $target -> $dest"
    fi
}

deploy_file() {
    local src="$1"
    local dest="$2"

    mkdir -p "$(dirname "$dest")"
    backup_item "$dest"

    if [ "$INSTALL_MODE" = "symlink" ]; then
        ln -snf "$src" "$dest"
        success "Enlazado: $dest -> $src"
    else
        cp -r "$src" "$dest"
        success "Copiado: $dest"
    fi
}

main() {
    echo -e "${C_BOLD}=== Instalador de Configuración de Niri y Scripts ===${C_RESET}"
    echo "Directorio de origen: $DOTFILES_DIR"
    echo "Modo de instalación: $INSTALL_MODE"
    echo ""

    if [ "$ASSUME_YES" = false ]; then
        if [ "$INSTALL_PKGS" = false ]; then
            read -rp "¿Deseas intentar instalar paquetes/dependencias del sistema ahora? (s/N): " resp
            if [[ "$resp" =~ ^[sSyY] ]]; then
                INSTALL_PKGS=true
            fi
        fi
    fi

    if [ "$INSTALL_PKGS" = true ]; then
        install_packages
    fi

    # 1. Crear directorios base
    mkdir -p "$HOME/.config" "$HOME/.local/bin"

    # 2. Desplegar ~/.config/niri
    info "Desplegando configuración de Niri..."
    deploy_file "$DOTFILES_DIR/.config/niri" "$HOME/.config/niri"

    # 3. Desplegar ~/.config/kitty
    info "Desplegando configuración de Kitty..."
    deploy_file "$DOTFILES_DIR/.config/kitty" "$HOME/.config/kitty"

    # 4. Desplegar ~/.config/copyq
    info "Desplegando configuración de CopyQ..."
    deploy_file "$DOTFILES_DIR/.config/copyq" "$HOME/.config/copyq"

    # 5. Desplegar scripts en ~/.local/bin
    info "Desplegando scripts en $HOME/.local/bin..."
    for file in "$DOTFILES_DIR"/bin/*; do
        local basename
        basename="$(basename "$file")"
        if [ -L "$file" ]; then
            # Es un symlink dentro de bin/
            local target
            target="$(readlink "$file")"
            backup_item "$HOME/.local/bin/$basename"
            ln -sf "$target" "$HOME/.local/bin/$basename"
            success "Symlink creado: $HOME/.local/bin/$basename -> $target"
        elif [ -f "$file" ]; then
            deploy_file "$file" "$HOME/.local/bin/$basename"
            chmod +x "$HOME/.local/bin/$basename"
        fi
    done

    # 5. Asegurar PATH en shells (~/.bashrc, ~/.zshrc, ~/.profile)
    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [ -f "$rc" ]; then
            if ! grep -q '\.local/bin' "$rc"; then
                echo "" >> "$rc"
                echo "# Agregado por dotfiles-niri" >> "$rc"
                echo "$path_line" >> "$rc"
                info "Agregado ~/.local/bin al PATH en $rc"
            fi
        fi
    done

    # 6. Validación de Niri
    echo ""
    if command -v niri >/dev/null 2>&1; then
        info "Validando configuración con 'niri validate'..."
        if niri validate >/dev/null 2>&1; then
            success "¡Configuración de Niri válida y lista para usar!"
        else
            warn "Niri reportó advertencias en la validación. Ejecuta 'niri validate' para ver los detalles."
        fi
    else
        warn "Niri no está instalado actualmente en el sistema."
    fi

    echo ""
    echo -e "${C_GREEN}${C_BOLD}¡Instalación completada con éxito!${C_RESET}"
    if [ -d "$BACKUP_DIR" ]; then
        info "Tus configuraciones previas fueron respaldadas en: $BACKUP_DIR"
    fi
    echo -e "Puedes iniciar tu sesión de Niri seleccionándola desde tu Display Manager (GDM, SDDM, Ly, etc.) o ejecutando ${C_BOLD}niri${C_RESET}."
}

main "$@"
