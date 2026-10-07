#!/usr/bin/env bash
set -euo pipefail

hyprctl dispatch "hl.dsp.workspace.toggle_special('desktop')" >/dev/null 2>&1 || true
