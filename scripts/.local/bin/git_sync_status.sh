#!/bin/bash
DOTFILES_DIR="$HOME/dotfiles"

# Must match the UI_TARGETS array in void script exactly
UI_TARGETS=(
    ".config/niri/config.kdl:niri/.config/niri/config.kdl"
    ".config/waybar/config.jsonc:waybar/.config/waybar/config.jsonc"
    ".config/waybar/style.css:waybar/.config/waybar/style.css"
    ".config/swayidle/config:swayidle/.config/swayidle/config"
    ".config/kanshi/config:kanshi/.config/kanshi/config"
    ".config/gtklock/style.css:gtklock/.config/gtklock/style.css"
    ".config/gtklock/config.ini:gtklock/.config/gtklock/config.ini"
    ".config/kitty/kitty.conf:kitty/.config/kitty/kitty.conf"
    ".config/starship.toml:starship/.config/starship.toml"
)

# 1. LIVE AUDIT: Check if any decoupled file has drifted from vault
DRIFT_DETECTED=0
for entry in "${UI_TARGETS[@]}"; do
    SRC="${entry%%:*}"
    DEST="${entry#*:}"
    
    if ! diff -q "$HOME/$SRC" "$DOTFILES_DIR/$DEST" &>/dev/null; then
        DRIFT_DETECTED=1
        break
    fi
done

cd "$DOTFILES_DIR" || exit

# 2. GIT STATUS: Check for uncommitted changes in the vault
STATUS=$(git status --porcelain)
LOCAL=$(git rev-parse @ 2>/dev/null)
REMOTE=$(git rev-parse "origin/main" 2>/dev/null)
ICON="󰘬"

sanitize() {
    sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g'
}

# 3. PRIORITY LOGIC
if [[ $DRIFT_DETECTED -eq 1 || -n "$STATUS" ]]; then
    echo "{\"text\": \"$ICON\", \"tooltip\": \"󱈸 UNCOMMITTED OR LIVE CHANGES\", \"class\": \"dirty\"}"
elif [[ -n "$LOCAL" && -n "$REMOTE" && "$LOCAL" != "$REMOTE" ]]; then
    HISTORY=$(git log -3 --format="- %s (%ar)" origin/main..HEAD 2>/dev/null | sanitize)
    echo "{\"text\": \"$ICON\", \"tooltip\": \"󰇚 UNPUSHED COMMITS:\\n$HISTORY\", \"class\": \"unpushed\"}"
else
    HISTORY=$(git log -3 --format="- %s (%ar)" 2>/dev/null | sanitize)
    echo "{\"text\": \"$ICON\", \"tooltip\": \"✅ SYNCED\\n$HISTORY\", \"class\": \"clean\"}"
fi
