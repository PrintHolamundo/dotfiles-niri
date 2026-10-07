# 🌌 Dotfiles: Niri & Custom Scripts

Configuración completa y modular del compositor scrollable Wayland **Niri**, la suite de escritorio **DankMaterialShell (DMS)**, la terminal **Kitty**, y una suite de scripts personalizados para productividad, gestión de hardware/monitores, control de audio y utilidades del sistema.

Preparado y optimizado especialmente para **Fedora** y extensible a cualquier distribución de Linux (Arch Linux, Ubuntu/Debian, etc.).

---

## 📁 Estructura del Repositorio

```text
dotfiles-niri/
├── .config/
│   ├── niri/                     # Configuración modular de Niri
│   │   ├── config.kdl            # Archivo maestro que incluye los módulos
│   │   ├── gpu.kdl               # Configuración de renderizado GPU
│   │   ├── dms/                  # Módulos de integración con DankMaterialShell
│   │   │   ├── colors.kdl        # Colores y temas sincronizados
│   │   │   ├── layout.kdl        # Bordes activos/inactivos de DMS
│   │   │   ├── alttab.kdl        # Configuración de conmutación de ventanas
│   │   │   └── cursor.kdl        # Cursor integrado
│   │   └── cfg/
│   │       ├── animation.kdl     # Curvas y tiempos de animación
│   │       ├── autostart.kdl     # Aplicaciones y servicios al iniciar sesión
│   │       ├── display.kdl       # Configuración de salidas/monitores (3440x1440@120Hz)
│   │       ├── input.kdl         # Teclado, mouse, touchpad
│   │       ├── keybinds.kdl      # Atajos de teclado completos (DMS + Apps)
│   │       ├── layout.kdl        # Espaciado (gaps), proporciones y fondo
│   │       ├── misc.kdl          # Preferencias generales y compatibilidad Wayland
│   │       └── rules.kdl         # Reglas de ventanas (flotantes, scratchpads, Omnissa)
│   ├── copyq/                    # Gestor de portapapeles CopyQ
│   │   ├── copyq.conf            # Configuración principal
│   │   ├── copyq-commands.ini    # Comandos (encriptación, etiquetas, fijar)
│   │   └── copyq_tabs.ini        # Definición de pestañas
│   └── kitty/                    # Terminal Kitty
│       ├── kitty.conf            # Configuración principal
│       ├── user.conf             # Preferencias de usuario (transparencia, clic derecho Windows-style)
│       ├── dank-theme.conf       # Tema sincronizado con DMS
│       ├── dank-tabs.conf        # Configuración de pestañas Dank
│       ├── current-font.conf     # Fuente tipográfica
│       ├── current-theme.conf    # Paleta de colores
│       └── mouse_action.py       # Lógica personalizada de copiar/pegar con mouse
├── bin/                          # Suite de scripts ejecutables (~/.local/bin)
│   ├── audio_*.sh                # Conmutadores de salida de audio (Blue, Bocinas, Audífonos G535)
│   ├── monitor_picker.py         # Selector interactivo de monitores y persistencia
│   ├── ocr-grab                  # Capturador OCR de pantalla al portapapeles
│   ├── show-batteries.sh         # Consulta rápida de baterías de periféricos
│   ├── switch-session            # Conmutador entre sesiones (Niri, Hyprland, KDE)
│   ├── toggle_*.sh               # Scratchpads interactivos (Kitty, Gemini, Omnissa, Btop)
│   └── ...                       # Scripts de integración Sunshine / Headless / RGB
├── install.sh                    # Script instalador automático con detección de distro
├── install-system-deps.sh        # Instalador de dependencias y drivers para Fedora
└── README.md
```

---

## 🚀 Instalación Rápida

Clona este repositorio y ejecuta el instalador:

```bash
git clone https://github.com/PrintHolamundo/dotfiles-niri.git ~/dotfiles-niri
cd ~/dotfiles-niri
chmod +x install.sh install-system-deps.sh
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

## 🖥️ Optimización de Hardware (Fedora)

### GPU: NVIDIA GeForce RTX 5070 (Blackwell)
- Controladores oficiales `akmod-nvidia` y `xorg-x11-drv-nvidia-cuda` desde RPM Fusion.
- Módulos del kernel compilados y soporte para aceleración por hardware bajo Wayland.

### Pantalla Ultrawide (Xiaomi Mi Monitor 34")
- Resolución nativa configurada a **3440x1440 @ 120.000 Hz** en `display.kdl` y `monitor_picker.py` para máxima estabilidad y fluidez sin parpadeos.

### Audio PipeWire
- Scripts rápidos para alternar entre perfiles de audio sin abrir menús:
  - Audífonos inalámbricos Logitech G535 (`Mod + Inicio`)
  - Bocinas principales de escritorio (`Mod + RePág`)
  - Interfaz / Micrófono Blue Microphones (`Mod + AvPág`)

---

## 🛠️ Scripts Personalizados Incluidos (`bin/`)

### 📌 Scratchpads y Ventanas Emergentes (Toggle)
- **`toggle_kitty.sh`** (`Mod + T`): Despliega u oculta un terminal Kitty flotante como scratchpad sin perturbar el mosaico activo.
- **`toggle_gemini.sh`** (`Mod + G`): Abre o conmuta la app de Brave Gemini en modo flotante y centrado.
- **`toggle_system_monitor.sh`** (`Mod + Escape`): Abre o conmuta el monitor de recursos del sistema (`btop`).
- **`toggle_omnissa.sh`** (`Mod + Z`): Alterna el cliente de escritorio remoto Omnissa Horizon en Workspace 2 con ancho calibrado.
- **`toggle_brave.sh`** / **`toggle_desktop.sh`**: Control y alternancia de ventanas y espacios.

### 🔊 Gestión de Audio
- **`audio_blue.sh`** (`Mod + AvPág`): Conmuta la salida por defecto al micrófono/DAC Blue Microphones.
- **`audio_bocinas.sh`** (`Mod + RePág`): Conmuta la salida de audio a las bocinas principales.
- **`audio_audifonos.sh`** (`Mod + Inicio`): Conmuta la salida de audio a los audífonos inalámbricos Logitech G535.
- **`toggle_record_blue.sh`** (`Alt + F10`): Inicia o detiene la grabación directa del micrófono Blue en segundo plano.

### 🖥️ Monitores y Entorno
- **`monitor_picker.py` / `monitor_picker.sh`** (`Mod + P`): Selector interactivo para activar, apagar o combinar pantallas conectadas con persistencia automática en `display.kdl`.
- **`niri-headless-check.sh`**: Detección y preparación de sesiones headless / virtuales en arranque.
- **`sunshine_*`**: Scripts de integración para streaming remoto de Sunshine hacia clientes externos (MacBook, Moonlight).
- **`switch-session`**: Utilidad para alternar de manera limpia entre escritorios (Niri, Hyprland, KDE Plasma) configurando SDDM autologin.

### ⚡ Herramientas y Productividad
- **`get-peripherals`**: Consulta el nivel de batería real de hardware Logitech (MX Master 3S, K400 Plus vía Solaar/HID++) y audífonos G535 (vía HeadsetControl) actualizando la caché local.
- **`show-batteries.sh`** (`bateria`, `battery`, `Mod + Alt + B`): Genera y notifica visualmente el estado detallado de batería de todos los periféricos conectados.
- **`solaar`** (`-w hide`): Autoiniciado en segundo plano para reflejar el estado e indicador de batería de periféricos Logitech en la bandeja del sistema (System Tray) de la barra.
- **`ocr-grab`** (`Mod + Shift + T`): Permite seleccionar un área de la pantalla con `grim` + `slurp`, extraer el texto usando OCR (`tesseract` en español e inglés) y copiarlo al portapapeles al instante.
- **`rgb-controller.sh`**: Control por software de iluminación de periféricos vía OpenRGB.

---

## ⌨️ Atajos de Teclado Principales (Cheat Sheet)

### DankMaterialShell (DMS) & Sistema
| Atajo | Acción |
|---|---|
| `Mod + Space` | Abrir lanzador de aplicaciones (DMS Spotlight) |
| `Alt + Space` | Barra de búsqueda rápida (Spotlight Bar) |
| `Mod + S` | Panel de Control / Dashboard |
| `Mod + Shift + S` | Configuración del Sistema (DMS Settings) |
| `Mod + Shift + Return` | Selector de Fondos de Pantalla (DMS Wallpaper) |
| `Mod + Alt + L` | Bloqueo de pantalla (DMS Lock) |
| `Mod + Shift + Q` | Menú de energía / Salir (DMS Powermenu) |

### Aplicaciones y Productividad
| Atajo | Acción |
|---|---|
| `Mod + Return` | Abrir terminal Kitty |
| `Mod + B` | Abrir navegador Brave |
| `Mod + N` | Abrir editor de código (VS Code) |
| `Mod + E` | Abrir explorador de archivos (Nautilus) |
| `Mod + Z` | Alternar Omnissa Horizon Client (Workspace 2) |
| `Mod + V` / `Alt + V` | **Portapapeles:** Toggle CopyQ |
| `Mod + T` | **Scratchpad:** Terminal Kitty flotante |
| `Mod + G` | **Scratchpad:** Gemini AI (Brave App) |
| `Mod + Escape` | **Scratchpad:** Monitor de sistema (`btop`) |
| `Mod + Alt + B` | **Batería:** Consultar niveles de periféricos (mouse, audífonos, teclado) |
| `Mod + P` | Selector interactivo de monitores |
| `Mod + Shift + T` | **OCR:** Capturar y extraer texto de pantalla al portapapeles |

### Gestión de Audio
| Atajo | Acción |
|---|---|
| `Mod + Inicio` | Cambiar audio a Audífonos Logitech G535 |
| `Mod + RePág` | Cambiar audio a Bocinas de escritorio |
| `Mod + AvPág` | Cambiar audio a Micrófono / DAC Blue |
| `XF86AudioRaiseVolume` | Subir volumen (DMS) |
| `XF86AudioLowerVolume` | Bajar volumen (DMS) |
| `XF86AudioMute` | Silenciar volumen (DMS) |
| `Mod + Ctrl + Space` | Pausar / Reanudar reproducción multimedia |
| `Mod + Ctrl + Right / Left` | Pista siguiente / anterior |

### Ventanas y Navegación Niri
| Atajo | Acción |
|---|---|
| `Mod + Q` | Cerrar ventana activa |
| `Mod + H / J / K / L` | Navegación entre columnas y ventanas (izquierda/abajo/arriba/derecha) |
| `Mod + Ctrl + H / L` | Mover columna a la izquierda / derecha |
| `Mod + Ctrl + K / J` | Mover ventana arriba / abajo |
| `Mod + F` | Maximizar columna |
| `Mod + Shift + F` | Alternar pantalla completa (fullscreen) |
| `Mod + Shift + V` | Alternar foco entre flotante y mosaico |
| `Mod + R` / `Mod + Shift + R` | Cambiar ancho de columna predefinido (siguiente / anterior) |
| `Mod + 1..9` | Cambiar al espacio de trabajo (Workspace) 1 a 9 |
| `Mod + Ctrl + 1..9` | Mover columna al espacio de trabajo 1 a 9 |

---

## 📄 Licencia

Este repositorio está disponible bajo la licencia MIT. Siéntete libre de adaptarlo y personalizarlo para tu propio flujo de trabajo.
