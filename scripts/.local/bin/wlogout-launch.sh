#!/bin/bash
# Get focused monitor resolution via niri
resolution=$(niri msg outputs 2>/dev/null | grep -A 5 "focused" | grep "Mode" | grep -oP '\d+x\d+' | head -1)
width=$(echo $resolution | cut -d'x' -f1)
height=$(echo $resolution | cut -d'x' -f2)

# Fallback
if [ -z "$height" ]; then
    height=1200
    width=1920
fi

y_margin=$((height * 46 / 100))
x_margin=$((width * 38 / 100))

wlogout -b 5 -T $y_margin -B $y_margin -L $x_margin -R $x_margin
