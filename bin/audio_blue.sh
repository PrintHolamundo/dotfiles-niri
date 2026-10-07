#!/bin/bash

SINK="alsa_output.usb-Generic_Blue_Microphones_201701110001-00.analog-stereo"

pactl set-default-sink "$SINK"

notify-send -t 1500 -h string:x-kde-substitutions:0 \
  "Audio Output" "Cambiado a: Blue Microphones"