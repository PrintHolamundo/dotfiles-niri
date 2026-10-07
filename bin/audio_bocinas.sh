#!/bin/bash

SINK="alsa_output.pci-0000_00_1f.3.analog-stereo"

pactl set-default-sink "$SINK"

notify-send -t 1500 -h string:x-kde-substitutions:0 \
  "Audio Output" "Cambiado a: Bocinas"