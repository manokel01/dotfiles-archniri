#!/bin/bash
pactl set-source-mute @DEFAULT_SOURCE@ toggle
if pactl get-source-mute @DEFAULT_SOURCE@ | grep -q "yes"; then
    echo 0 | sudo tee /sys/class/leds/platform::micmute/brightness
else
    echo 1 | sudo tee /sys/class/leds/platform::micmute/brightness
fi
swayosd-client --input-volume mute-toggle
