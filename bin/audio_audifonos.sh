#!/bin/bash

SINK="alsa_output.usb-Logitech_G535_Wireless_Gaming_Headset-00.analog-stereo"

pactl set-default-sink "$SINK"

notify-send -t 1500 -h string:x-kde-substitutions:0 \
  "Audio Output" "Cambiado a: Audífonos Logitech G535"