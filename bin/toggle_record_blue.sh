#!/usr/bin/env python3
import os
import sys
import time
import signal
import datetime
import subprocess

BLUE_DEVICE_NAME = "alsa_input.usb-Generic_Blue_Microphones_201701110001-00.analog-stereo"
SAVE_DIR = os.path.expanduser("~/AUDIOS/")
PID_FILE = "/tmp/recording_blue.pid"
INFO_FILE = "/tmp/recording_blue.info"

os.makedirs(SAVE_DIR, exist_ok=True)

# 1. Si ya está grabando -> DETENER
if os.path.exists(PID_FILE):
    pid = None
    try:
        with open(PID_FILE, "r") as f:
            pid = int(f.read().strip())
    except Exception:
        pid = None

    is_running = False
    if pid:
        try:
            os.kill(pid, 0)
            is_running = True
        except OSError:
            is_running = False

    if is_running:
        # Enviar SIGINT para que ffmpeg guarde limpiamente el archivo MP3
        os.kill(pid, signal.SIGINT)

        # Esperar a que el proceso finalice (máximo 3 segundos)
        for _ in range(30):
            try:
                os.kill(pid, 0)
                time.sleep(0.1)
            except OSError:
                break

        # Leer datos guardados
        mic_name = "Micrófono"
        filename = "Grabación"
        if os.path.exists(INFO_FILE):
            try:
                with open(INFO_FILE, "r") as f:
                    lines = f.read().splitlines()
                    if len(lines) >= 1:
                        filename = os.path.basename(lines[0])
                    if len(lines) >= 2:
                        mic_name = lines[1]
            except Exception:
                pass

        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
        if os.path.exists(INFO_FILE):
            os.remove(INFO_FILE)

        subprocess.run([
            "notify-send", "-t", "4000", "-i", "media-playback-stop",
            "⏹ Grabación finalizada",
            f"Micrófono: {mic_name}\nGuardado en:\n{filename}"
        ])
        sys.exit(0)
    else:
        # Archivo PID huérfano
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
        if os.path.exists(INFO_FILE):
            os.remove(INFO_FILE)

# 2. No está grabando -> INICIAR
def get_available_sources():
    try:
        out = subprocess.check_output(["pactl", "list", "sources"]).decode("utf-8", errors="replace")
    except Exception:
        return []

    sources = []
    curr_name = ""
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("Name:"):
            curr_name = line.split("Name:", 1)[1].strip()
        elif line.startswith("Description:"):
            desc = line.split("Description:", 1)[1].strip()
            if curr_name and not curr_name.endswith(".monitor"):
                sources.append((curr_name, desc))
            curr_name = ""
    return sources

sources = get_available_sources()
selected_device = None
selected_desc = None

# Buscar si el Blue Microphone está conectado y disponible
for name, desc in sources:
    if "Blue" in desc or BLUE_DEVICE_NAME in name:
        selected_device = name
        selected_desc = desc
        break

# Si Blue Microphone NO está disponible:
if not selected_device:
    if not sources:
        subprocess.run([
            "notify-send", "-t", "4000", "-i", "dialog-error",
            "❌ No se puede grabar",
            "No se detectó ningún micrófono disponible en el sistema."
        ])
        sys.exit(1)

    # Avisar en la notificación que Blue no está conectado
    subprocess.run([
        "notify-send", "-t", "3500", "-i", "dialog-warning",
        "⚠️ Micrófono Blue no detectado",
        "Por favor, selecciona en la ventana con cuál micrófono deseas grabar..."
    ])

    # Preguntar con kdialog qué micrófono usar
    kdialog_cmd = [
        "kdialog",
        "--title", "Seleccionar Micrófono",
        "--radiolist", "El micrófono Blue no está conectado.\n¿Con cuál micrófono deseas grabar?"
    ]
    for i, (name, desc) in enumerate(sources):
        status = "on" if i == 0 else "off"
        kdialog_cmd.extend([name, desc, status])

    try:
        proc = subprocess.run(
            kdialog_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True
        )
        choice = proc.stdout.strip()
        if proc.returncode != 0 or not choice:
            subprocess.run([
                "notify-send", "-t", "3000", "-i", "dialog-information",
                "Grabación cancelada",
                "No se seleccionó ningún micrófono."
            ])
            sys.exit(0)

        selected_device = choice
        for name, desc in sources:
            if name == selected_device:
                selected_desc = desc
                break
        if not selected_desc:
            selected_desc = selected_device
    except Exception:
        selected_device = sources[0][0]
        selected_desc = sources[0][1]

# 3. Iniciar proceso de grabación con ffmpeg
timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
filepath = os.path.join(SAVE_DIR, f"grabacion_{timestamp}.mp3")

ffmpeg_cmd = [
    "ffmpeg", "-nostdin", "-loglevel", "error",
    "-f", "pulse", "-i", selected_device,
    "-c:a", "libmp3lame", "-q:a", "2",
    filepath
]

rec_proc = subprocess.Popen(
    ffmpeg_cmd,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    stdin=subprocess.DEVNULL,
    start_new_session=True
)

# Verificar que ffmpeg arrancó correctamente
time.sleep(0.3)
if rec_proc.poll() is not None:
    subprocess.run([
        "notify-send", "-t", "4000", "-i", "dialog-error",
        "❌ Error al iniciar grabación",
        f"No se pudo conectar al micrófono:\n{selected_desc}"
    ])
    sys.exit(1)

with open(PID_FILE, "w") as f:
    f.write(str(rec_proc.pid))

with open(INFO_FILE, "w") as f:
    f.write(f"{filepath}\n{selected_desc}\n")

subprocess.run([
    "notify-send", "-t", "3000", "-i", "audio-input-microphone",
    "🔴 Grabando audio...",
    f"Micrófono: {selected_desc}\nPresiona Alt+F10 para detener"
])
