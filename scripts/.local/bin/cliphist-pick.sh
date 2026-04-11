#!/bin/bash
# Standalone cliphist picker — replaces `walker -m clipboard`
# Launched in a floating kitty terminal via keybind (Mod+Shift+V)
# Requires: cliphist, fzf, wl-clipboard

selected=$(cliphist list | fzf \
    --prompt="Clipboard ❯ " \
    --info=hidden \
    --layout=reverse \
    --color="bg:#000000,fg:#ffffff,hl:#555555,prompt:#ffffff,pointer:#ffffff" \
    --border=none)

# Exit if nothing selected (Escape pressed)
[ -z "$selected" ] && exit 0

# Decode and copy back to clipboard
echo "$selected" | cliphist decode | wl-copy

notify-send "Clipboard" "Item copied to clipboard" -t 1500
