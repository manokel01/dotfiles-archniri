#!/bin/bash
PROFILE=$(powerprofilesctl get)

case $PROFILE in
    "power-saver")
        ICON="󰌪"
        TEXT="Power Saver (Battery Optimized)"
        ;;
    "balanced")
        ICON="󰾆"
        TEXT="Balanced (Standard)"
        ;;
    "performance")
        ICON="󰓅"
        TEXT="Performance (High Power)"
        ;;
esac

echo "{\"text\": \"$ICON\", \"tooltip\": \"$TEXT\"}"
