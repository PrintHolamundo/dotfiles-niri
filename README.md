# 🌌 Dotfiles: Niri & Custom Scripts

Configuración completa y modular del compositor scrollable Wayland **Niri**, la terminal **Kitty**, y una suite de scripts personalizados para productividad, gestión de monitores, control de audio y utilidades del sistema.

Preparado para desplegarse fácilmente en cualquier distribución de Linux (Arch Linux, Fedora, Ubuntu/Debian, etc.).

---

## 📁 Estructura del Repositorio

```text
dotfiles-niri/
├── .config/
│   ├── niri/                     # Configuración modular de Niri
│   │   ├── config.kdl            # Archivo maestro que incluye los módulos
│   │   ├── gpu.kdl               # Configuración de renderizado GPU
│   │   └── cfg/
│   │       ├── animation.kdl     # Curvas y tiempos de animación
│   │       ├── autostart.kdl     # Aplicaciones al iniciar sesión
│   │       ├── display.kdl       # Configuración activa de salidas/monitores
│   │       ├── input.kdl         # Teclado, mouse, touchpad
│   │       ├── keybinds.kdl      # Atajos de teclado completos
│   │       ├── layout.kdl        # Espaciado (gaps), bordes, proporciones
│   │       ├── misc.kdl          # Preferencias generales
│   │       └── rules.kdl         # Reglas de ventanas (flotantes, scratchpads, tamaños)
│   └── kitty/                    # Terminal Kitty
│       ├── kitty.conf            # Configuración principal
│       ├── user.conf             # Preferencias de usuario (transparencia, clic derecho Windows-style)
│       ├── current-font.conf     # Fuente tipográfica
│       ├── current-theme.conf    # Paleta de colores
│       └── mouse_action.py       # Lógica personalizada de copiar/pegar con mouse
├── bin/                          # Suite de scripts ejecutables (~/.local/bin)
│   ├── audio_*.sh                # Conmutadores de salida de audio (Blue, Bocinas, Audífonos)
│   ├── monitor_picker.py         # Selector interactivo de monitores y persistencia
│   ├── ocr-grab                  # Capturador OCR de pantalla al portapapeles
│   ├── show-batteries.sh         # Consulta rápida de baterías de periféricos
│   ├── switch-session            # Conmutador entre sesiones (Niri, Hyprland, KDE)
│   ├── toggle_*.sh               # Scratchpads interactivos (Kitty, Gemini, Btop, etc.)
│   └── ...                       # Scripts de integración Sunshine / Headless / RGB
├── install.sh                    # Script instalador automático con detección de distro
└── README.md
```

---

## 🚀 Instalación Rápida

Clona este repositorio y ejecuta el instalador:

```bash
git clone https://github.com/PrintHolamundo/dotfiles-niri.git ~/dotfiles-niri
cd ~/dotfiles-niri
chmod +x install.sh
./install.sh
```

### Opciones del Instalador

| Parámetro | Descripción |
|---|---|
| `-s`, `--symlink` | **(Recomendado)** Crea enlaces simbólicos hacia `~/.config` y `~/.local/bin`, permitiendo versionar cambios en Git en tiempo real. |
| `-c`, `--copy` | Copia los archivos en vez de crear enlaces simbólicos. |
| `-p`, `--packages` | Detecta tu distribución e instala automáticamente paquetes y dependencias del sistema. |
| `-y`, `--yes` | Ejecuta en modo no interactivo (asume sí a las preguntas). |

> [!NOTE]
> El instalador realiza automáticamente una copia de seguridad (`~/.config/dotfiles_backup_<timestamp>`) de cualquier archivo existente antes de modificarlo o sobreescribirlo.

---

## 📦 Dependencias y Paquetes por Distribución

### Arch Linux / Arch-based (EndeavourOS, Manjaro, etc.)

```bash
paru -S --needed niri kitty jq wl-clipboard grim slurp tesseract tesseract-data-eng tesseract-data-spa libnotify pipewire pipewire-pulse wireplumber btop python
```

### Fedora

```bash
# Habilitar repositorio copr de Niri
sudo dnf copr enable yalter/niri
sudo dnf install -y niri kitty jq wl-clipboard grim slurp tesseract libnotify pipewire-pulseaudio wireplumber btop python3
```

### Debian / Ubuntu

```bash
sudo apt update
sudo apt install -y kitty jq wl-clipboard grim slurp tesseract-ocr libnotify-bin pulseaudio-utils btop python3
# Para Niri, consulta la documentación oficial o descarga el binario/compila con cargo.
```

---

## 🛠️ Scripts Personalizados Incluidos (`bin/`)

### 📌 Scratchpads y Ventanas Emergentes (Toggle)
- **`toggle_kitty.sh`** (`Mod + T`): Despliega u oculta un terminal Kitty flotante en pantalla completa como scratchpad sin perturbar el mosaico activo.
- **`toggle_gemini.sh`** (`Mod + G`): Abre o conmuta la app de Brave Gemini en modo flotante y centrado.
- **`toggle_system_monitor.sh`** (`Mod + Escape`): Abre o conmuta el monitor de recursos del sistema (`btop`).
- **`toggle_omnissa.sh`** (`Mod + Z`): Alterna el cliente de escritorio remoto Omnissa Horizon.
- **`toggle_ryotunes.sh`** (`Mod + M`): Conmuta el reproductor de música.
- **`toggle_brave.sh`** / **`toggle_desktop.sh`**: Control y alternancia de navegadores y espacios.

### 🔊 Gestión de Audio
- **`audio_blue.sh`** (`Mod + AvPág`): Conmuta la salida por defecto al micrófono/DAC Blue Microphones.
- **`audio_bocinas.sh`** (`Mod + RePág`): Conmuta la salida de audio a las bocinas principales.
- **`audio_audifonos.sh`** (`Mod + Inicio`): Conmuta la salida de audio a los audífonos inalámbricos (Logitech G535).
- **`toggle_record_blue.sh`** (`Alt + F10`): Inicia o detiene la grabación directa del micrófono Blue en segundo plano.
- **`ryoku-volume`**: Ajuste y control unificado de niveles de volumen.

### 🖥️ Monitores y Entorno
- **`monitor_picker.py` / `monitor_picker.sh`** (`Mod + P`): Selector interactivo para activar, apagar o combinar pantallas conectadas (ej. DisplayPort, HDMI, ultra-wide) con persistencia automática en `display.kdl`.
- **`niri-headless-check.sh`**: Detección y preparación de sesiones headless / virtuales en arranque.
- **`sunshine_*`**: Scripts de integración para streaming remoto de Sunshine hacia clientes externos (MacBook, Moonlight).
- **`switch-session`**: Utilidad para alternar de manera limpia entre escritorios (Niri, Hyprland, KDE Plasma) configurando SDDM autologin.

### ⚡ Herramientas y Productividad
- **`ocr-grab`** (`Mod + Shift + T`): Permite seleccionar un área de la pantalla con `grim` + `slurp`, extraer el texto usando OCR (`tesseract`) y copiarlo al portapapeles al instante.
- **`show-batteries.sh`** (`battery`, `bateria`): Notifica y reporta los niveles de batería de periféricos conectados (mouse, audífonos, etc.).
- **`rgb-controller.sh`**: Control por software de iluminación de periféricos vía OpenRGB.

---

## ⌨️ Atajos de Teclado Principales (Cheat Sheet)

| Atajo | Acción |
|---|---|
| `Mod + Return` | Abrir terminal Kitty |
| `Mod + B` | Abrir navegador Brave |
| `Mod + E` | Abrir explorador de archivos (Nautilus) |
| `Mod + N` | Abrir editor de código (VS Code) |
| `Mod + T` | **Scratchpad:** Toggle terminal Kitty flotante |
| `Mod + G` | **Scratchpad:** Toggle Gemini AI |
| `Mod + Escape` | **Scratchpad:** Toggle monitor de sistema (`btop`) |
| `Mod + P` | Selector de monitores interactivo |
| `Mod + Shift + T` | **OCR:** Capturar y extraer texto de la pantalla |
| `Mod + Q` / `Mod + C` | Cerrar ventana activa |
| `Mod + H / J / K / L` | Navegación entre columnas y ventanas |
| `Mod + Shift + H / L` | Mover columna a la izquierda / derecha |
| `Mod + F` | Alternar pantalla completa (fullscreen) |
| `Mod + Shift + F` | Alternar ventana flotante |
| `Mod + R` | Cambiar ancho de columna predefinido |
| `Mod + Shift + Q` | Menú de sesión / Salir |

---

## 📄 Licencia

Este repositorio está disponible bajo la licencia MIT. Siéntete libre de adaptarlo y personalizarlo para tu propio flujo de trabajo.
