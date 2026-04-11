#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  arch-setup.sh — Phase 1 post-install setup
#  ThinkPad P14s Gen 4 AMD · Arch Linux · Niri
#
#  Run as manokel (not root) after archinstall completes and you have SSHed
#  back in from your MacBook:
#
#    bash <(curl -s https://raw.githubusercontent.com/manokel01/dotfiles-archniri/main/arch-setup.sh)
#
#  Steps:
#    01  paru (AUR helper)
#    02  pacman packages
#    03  AUR packages
#    04  zram-generator config
#    05  GRUB / os-prober (dual-boot Windows)
#    06  System services
#    07  wifi-resume.service  (ath11k_pci s2idle workaround)
#    08  DATA partition  (nvme0n1p4 → /mnt/data, fstab)
#    09  Snapper + snap-pac
#    10  User groups  (i2c for ddcutil, etc.)
#    11  Reflector (mirror list)
#    12  Dotfiles clone + stow
#    13  User config  (gtklock service, mimeapps, bashrc aliases)
#    14  Local scripts  (pacman_updates.sh, check_locks.sh)
#    15  Final grub-mkconfig + summary
#
#  DECISIONS:
#    · wireplumber is NOT version-pinned
#    · No swap partition — zram-generator instead
#    · AppArmor + ufw (not SELinux)
#    · Thunar (not Dolphin) — no kvantum / qt6ct / portal-kde
#    · Dotfiles cloned via HTTPS; switch remote to SSH after key setup
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail
IFS=$'\n\t'

# ── colour helpers ─────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

step() { echo -e "\n${BOLD}${CYAN}━━  $*  ━━${NC}"; }
ok()   { echo -e "  ${GREEN}✔${NC}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $*"; }
die()  { echo -e "\n${RED}✗  $*${NC}\n" >&2; exit 1; }

# ── guards ─────────────────────────────────────────────────────────────────────
[[ "$EUID" -eq 0 ]]         && die "Do NOT run as root. Run as manokel with sudo access."
[[ "$USER"  != "manokel" ]] && die "Expected user 'manokel', got '$USER'. Abort."

# ── constants ──────────────────────────────────────────────────────────────────
DOTFILES_REPO_HTTPS="https://github.com/manokel01/dotfiles-archniri.git"
DOTFILES_REPO_SSH="git@github.com:manokel01/dotfiles-archniri.git"
DOTFILES_DIR="$HOME/dotfiles"
LOCAL_BIN="$HOME/.local/bin"
DATA_DEV="/dev/nvme0n1p4"   # NTFS DATA partition — shrunk to ~200 GB in Windows first

mkdir -p "$LOCAL_BIN"

# ══════════════════════════════════════════════════════════════════════════════
step "01/15  paru — AUR helper"
# ══════════════════════════════════════════════════════════════════════════════

if command -v paru &>/dev/null; then
    ok "paru already installed — skipping build."
else
    sudo pacman -S --needed --noconfirm git base-devel

    PTMP=$(mktemp -d)
    trap 'rm -rf "$PTMP"' EXIT

    git clone https://aur.archlinux.org/paru.git "$PTMP/paru"
    ( cd "$PTMP/paru" && makepkg -si --noconfirm )

    trap - EXIT
    rm -rf "$PTMP"
    ok "paru installed."
fi

# ══════════════════════════════════════════════════════════════════════════════
step "02/15  pacman packages"
# ══════════════════════════════════════════════════════════════════════════════

PACMAN_PKGS=(
    # ── Display / GPU ──────────────────────────────────────────────────────
    mesa
    vulkan-radeon              # RADV driver for Ryzen 7840U iGPU

    # ── Compositor / session ───────────────────────────────────────────────
    xdg-desktop-portal-gtk     # file picker / portal (no portal-kde needed: Thunar chosen)

    # ── Status bar ─────────────────────────────────────────────────────────
    waybar

    # ── Idle management ────────────────────────────────────────────────────
    swayidle                   # replaces hypridle; battery/AC dual-path

    # ── Terminal / editor ──────────────────────────────────────────────────
    kitty
    micro

    # ── Audio (no wireplumber version pin — confirmed decision) ────────────
    pipewire
    pipewire-pulse
    pipewire-alsa
    wireplumber
    pavucontrol

    # ── Bluetooth ──────────────────────────────────────────────────────────
    bluez
    bluez-utils

    # ── Screenshot / clipboard ─────────────────────────────────────────────
    grim
    slurp
    wl-clipboard               # wl-copy / wl-paste
    cliphist                   # clipboard history daemon

    # ── Media controls ─────────────────────────────────────────────────────
    playerctl

    # ── File management ────────────────────────────────────────────────────
    thunar                     # GUI file manager (no Dolphin — avoids KDE Qt weight)
    gvfs                       # virtual filesystem support for Thunar
    yazi                       # terminal file manager
    ntfs-3g                    # NTFS support (DATA partition + Windows r/w)

    # ── Brightness control ─────────────────────────────────────────────────
    ddcutil                    # external monitor brightness (DDC/CI)

    # ── Network ────────────────────────────────────────────────────────────
    network-manager-applet

    # ── Fingerprint ────────────────────────────────────────────────────────
    fprintd

    # ── Firmware ───────────────────────────────────────────────────────────
    fwupd

    # ── Flatpak ────────────────────────────────────────────────────────────
    flatpak

    # ── GTK / Qt Wayland support ───────────────────────────────────────────
    qt5-wayland                # Qt 5 apps on Wayland (no qt6ct / kvantum needed)
    qt6-wayland                # Qt 6 apps on Wayland

    # ── Fonts & icons ──────────────────────────────────────────────────────
    ttf-nerd-fonts-symbols
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji

    # ── Shell & prompt ─────────────────────────────────────────────────────
    starship
    eza
    bash-completion

    # ── System monitoring & info ───────────────────────────────────────────
    btop
    fastfetch

    # ── PDF viewer ─────────────────────────────────────────────────────────
    zathura
    zathura-pdf-mupdf

    # ── Utilities ──────────────────────────────────────────────────────────
    libnotify                  # notify-send (used by existing scripts)
    jq                         # JSON parsing in scripts
    stow                       # dotfile management
    rclone                     # GDrive sync / DATA partition target

    # ── Authentication ─────────────────────────────────────────────────────
    polkit-gnome               # auth dialogs (spawn-at-startup in niri config)

    # ── Security ───────────────────────────────────────────────────────────
    apparmor                   # MAC layer (replaces SELinux from Fedora)
    ufw                        # firewall (replaces firewalld)
    audit                      # auditd — required for AppArmor logging

    # ── Arch maintenance tools ─────────────────────────────────────────────
    reflector                  # mirror list management
    pacman-contrib             # checkupdates (used by pacman_updates.sh)
    power-profiles-daemon

    # ── Snapper / Btrfs ────────────────────────────────────────────────────
    snapper
    btrfs-progs
    snap-pac                   # pacman hooks → auto pre/post snapshots

    # ── Swap replacement ───────────────────────────────────────────────────
    zram-generator             # compressed RAM swap; no swap partition needed

    # ── Bootloader helper ──────────────────────────────────────────────────
    os-prober                  # detects Windows; CRITICAL for GRUB dual-boot entry
)

sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
ok "pacman packages installed."

# ══════════════════════════════════════════════════════════════════════════════
step "03/15  AUR packages  (via paru)"
# ══════════════════════════════════════════════════════════════════════════════

AUR_PKGS=(
    niri           # Wayland compositor (scrollable-tiling, Rust)
    uwsm           # session manager; wrap app launches as 'uwsm app --'
    kanshi         # output management / clamshell lid profiles
    gtklock        # screen locker; GTK-based, replaces hyprlock/swaylock
    vicinae-bin    # app launcher (replaces Walker)
    niri-switch    # Alt+Tab window switcher (replaces walker -m windows)
    swaync         # notification daemon + panel (Super+N actively used)
    swayosd        # volume/brightness OSD
    nwg-look       # GTK theme picker for Wayland
    brave-bin      # browser
    rbw            # Bitwarden CLI (replaces walker bitwarden integration)
    wiremix        # optional audio TUI (btop covers basics; here for completeness)
)

paru -S --needed --noconfirm "${AUR_PKGS[@]}"
ok "AUR packages installed."

# ══════════════════════════════════════════════════════════════════════════════
step "04/15  zram-generator  (replaces swap partition)"
# ══════════════════════════════════════════════════════════════════════════════

sudo tee /etc/systemd/zram-generator.conf > /dev/null << 'EOF'
# zram-generator — matches Fedora's zram0 setup
# 64 GB RAM: cap at 8 GB compressed swap in RAM
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
EOF

ok "zram-generator configured (/etc/systemd/zram-generator.conf)."

# ══════════════════════════════════════════════════════════════════════════════
step "05/15  GRUB / os-prober  (Windows dual-boot)"
# ══════════════════════════════════════════════════════════════════════════════
# os-prober scans for other OSes. Disabled by default in GRUB 2.x for security.
# Must be explicitly re-enabled or Windows will not appear in the boot menu.

GRUB_DEFAULT="/etc/default/grub"

if grep -q '^GRUB_DISABLE_OS_PROBER' "$GRUB_DEFAULT"; then
    sudo sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$GRUB_DEFAULT"
    ok "GRUB_DISABLE_OS_PROBER set to false (updated existing line)."
else
    echo 'GRUB_DISABLE_OS_PROBER=false' | sudo tee -a "$GRUB_DEFAULT" > /dev/null
    ok "GRUB_DISABLE_OS_PROBER=false appended to /etc/default/grub."
fi

# AppArmor parameters: already set in archinstall.json, but verify they're present.
# If archinstall did not add them, inject them now.
if ! grep -q 'apparmor=1' "$GRUB_DEFAULT"; then
    warn "AppArmor kernel params not found in GRUB_CMDLINE_LINUX_DEFAULT — injecting now."
    sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 apparmor=1 security=apparmor"/' \
        "$GRUB_DEFAULT"
    ok "AppArmor params added to GRUB_CMDLINE_LINUX_DEFAULT."
fi

# First regeneration (final one comes at step 15 after DATA partition is ready)
sudo grub-mkconfig -o /boot/grub/grub.cfg
ok "GRUB config regenerated (first pass)."

# ══════════════════════════════════════════════════════════════════════════════
step "06/15  System services"
# ══════════════════════════════════════════════════════════════════════════════

SYSTEM_SERVICES=(
    NetworkManager
    bluetooth
    fprintd
    power-profiles-daemon
    fwupd
    reflector.timer
    apparmor
    ufw
    auditd
    snapper-cleanup.timer
)

for svc in "${SYSTEM_SERVICES[@]}"; do
    if sudo systemctl enable --now "$svc" 2>/dev/null; then
        ok "$svc enabled and started."
    else
        warn "$svc — enable failed (may need reboot or kernel module). Continuing."
    fi
done

# ufw: sensible defaults for a single-user desktop
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
ok "ufw enabled: deny incoming / allow outgoing."

# ══════════════════════════════════════════════════════════════════════════════
step "07/15  wifi-resume.service  (ath11k_pci s2idle workaround)"
# ══════════════════════════════════════════════════════════════════════════════
# The Qualcomm QCNFA765 (ath11k_pci) has a known s2idle resume bug where
# Wi-Fi does not reconnect after waking from suspend.
# Fix: unload and reload the kernel module after every resume.

sudo tee /usr/local/bin/wifi-resume > /dev/null << 'WIFISCRIPT'
#!/bin/sh
# Reload ath11k_pci after s2idle resume — QCNFA765 workaround
sleep 2
/usr/bin/modprobe -r ath11k_pci
/usr/bin/modprobe ath11k_pci
WIFISCRIPT
sudo chmod +x /usr/local/bin/wifi-resume

sudo tee /etc/systemd/system/wifi-resume.service > /dev/null << 'EOF'
[Unit]
Description=Reload ath11k_pci after suspend — Qualcomm QCNFA765 s2idle workaround
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wifi-resume
RemainAfterExit=no

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable wifi-resume.service
ok "wifi-resume.service created and enabled."

# ══════════════════════════════════════════════════════════════════════════════
step "08/15  DATA partition  (nvme0n1p4 → /mnt/data)"
# ══════════════════════════════════════════════════════════════════════════════
# NTFS DATA partition shared with Windows. Must have been shrunk to ~200 GB
# in Windows Disk Management before Arch install. Mounted read-write via ntfs3
# (kernel driver, faster than ntfs-3g FUSE) with uid/gid for manokel.

sudo mkdir -p /mnt/data

DATA_UUID=$(sudo blkid -s UUID -o value "$DATA_DEV" 2>/dev/null || true)

if [[ -z "$DATA_UUID" ]]; then
    warn "$DATA_DEV not found. Was the DATA partition shrunk and is the device path correct?"
    warn "Skipping fstab entry — add manually later with:"
    warn "  echo 'UUID=<uuid>  /mnt/data  ntfs3  uid=1000,gid=1000,umask=022,nofail  0  0' | sudo tee -a /etc/fstab"
else
    if grep -q "$DATA_UUID" /etc/fstab 2>/dev/null; then
        ok "DATA partition (UUID=$DATA_UUID) already in fstab — skipping."
    else
        printf 'UUID=%s\t/mnt/data\tntfs3\tuid=1000,gid=1000,umask=022,nofail\t0\t0\n' \
            "$DATA_UUID" | sudo tee -a /etc/fstab > /dev/null
        ok "fstab entry added: UUID=$DATA_UUID → /mnt/data (ntfs3)."
    fi
    # Test mount (nofail: failure here is non-fatal)
    sudo mount /mnt/data 2>/dev/null && ok "/mnt/data mounted." \
        || warn "Mount failed — reboot may be needed, or DATA was not yet shrunk."
fi

# ══════════════════════════════════════════════════════════════════════════════
step "09/15  Snapper"
# ══════════════════════════════════════════════════════════════════════════════
# snap-pac (installed above) fires pacman hooks to create pre/post snapshots
# automatically. Snapper needs a config for the root subvolume.

if sudo snapper list-configs 2>/dev/null | grep -q '^root\s'; then
    ok "Snapper 'root' config already exists — skipping creation."
else
    sudo snapper -c root create-config /
    ok "Snapper 'root' config created."
fi

# Conservative limits — enough history without filling the Btrfs pool
sudo sed -i \
    -e 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="5-10"/' \
    -e 's/^NUMBER_MIN_AGE=.*/NUMBER_MIN_AGE="1800"/' \
    -e 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="no"/' \
    /etc/snapper/configs/root 2>/dev/null || warn "Could not patch snapper config — edit /etc/snapper/configs/root manually."

ok "Snapper configured. snap-pac hooks active on pacman operations."

# ══════════════════════════════════════════════════════════════════════════════
step "10/15  User groups"
# ══════════════════════════════════════════════════════════════════════════════
# i2c:    required for ddcutil (external monitor brightness without sudo)
# video:  backlight access
# input:  input device access
# audio:  audio device access (pipewire should handle this, but belt-and-suspenders)

GROUPS=(i2c video input audio)
for grp in "${GROUPS[@]}"; do
    if getent group "$grp" &>/dev/null; then
        sudo usermod -aG "$grp" manokel
        ok "manokel added to group: $grp"
    else
        warn "Group '$grp' does not exist — skipping. (i2c: load module with 'sudo modprobe i2c-dev')"
    fi
done

# Ensure i2c-dev module loads on boot (required for ddcutil)
if ! grep -q 'i2c-dev' /etc/modules-load.d/*.conf 2>/dev/null; then
    echo 'i2c-dev' | sudo tee /etc/modules-load.d/i2c.conf > /dev/null
    ok "i2c-dev added to /etc/modules-load.d/i2c.conf (loads on boot)."
fi

# ══════════════════════════════════════════════════════════════════════════════
step "11/15  Reflector  (EU mirror list)"
# ══════════════════════════════════════════════════════════════════════════════

sudo tee /etc/xdg/reflector/reflector.conf > /dev/null << 'EOF'
# reflector.conf — EU mirrors, sorted by download rate
# Generated by arch-setup.sh
--country Greece,Germany,Netherlands,France
--protocol https
--age 12
--sort rate
--save /etc/pacman.d/mirrorlist
EOF

# Run once now to populate mirrorlist
sudo reflector --country Greece,Germany,Netherlands,France \
    --protocol https --age 12 --sort rate \
    --save /etc/pacman.d/mirrorlist 2>/dev/null \
    && ok "Mirrorlist updated." \
    || warn "reflector failed (no internet?). Will run automatically on next boot via reflector.timer."

# ══════════════════════════════════════════════════════════════════════════════
step "12/15  Dotfiles clone + stow"
# ══════════════════════════════════════════════════════════════════════════════
# Clone via HTTPS now (SSH key not set up yet post-install).
# After setting up your SSH key, switch the remote:
#   git -C ~/dotfiles remote set-url origin git@github.com:manokel01/dotfiles-archniri.git

if [[ -d "$DOTFILES_DIR/.git" ]]; then
    ok "Dotfiles repo already cloned — pulling."
    git -C "$DOTFILES_DIR" pull --ff-only \
        || warn "git pull failed — check status manually."
else
    git clone "$DOTFILES_REPO_HTTPS" "$DOTFILES_DIR"
    ok "Dotfiles cloned to $DOTFILES_DIR."
    echo ""
    echo -e "  ${YELLOW}Note:${NC} Cloned via HTTPS. After SSH key setup, run:"
    echo -e "  ${CYAN}  git -C ~/dotfiles remote set-url origin $DOTFILES_REPO_SSH${NC}"
fi

# Stow each package directory that exists in the repo.
# Phase 2 Chat C and D will populate niri/, waybar/, etc.
# This loop is idempotent — re-run anytime after new configs are added.
STOW_PKGS=(
    niri
    waybar
    kitty
    starship
    swaync
    swayidle
    gtklock
    yazi
)

echo ""
for pkg in "${STOW_PKGS[@]}"; do
    if [[ -d "$DOTFILES_DIR/$pkg" ]]; then
        stow -d "$DOTFILES_DIR" -t "$HOME" --restow "$pkg" \
            && ok "Stowed: $pkg" \
            || warn "stow failed for $pkg — check for conflicts in ~/"
    else
        warn "$pkg/ not in dotfiles repo yet — skipping (will stow after Chat C/D/E)."
    fi
done

# ══════════════════════════════════════════════════════════════════════════════
step "13/15  User config files"
# ══════════════════════════════════════════════════════════════════════════════

# ── gtklock systemd user service ──────────────────────────────────────────────
# NOT enabled by default. Triggered via keybind in niri config or by swayidle.
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/gtklock.service" << 'EOF'
[Unit]
Description=gtklock screen locker
Documentation=https://github.com/jovanlanik/gtklock
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/gtklock
Restart=on-failure
RestartSec=1

[Install]
WantedBy=graphical-session.target
EOF
ok "gtklock.service written to ~/.config/systemd/user/ (NOT enabled — trigger via keybind/swayidle)."

# ── MIME associations — Thunar as default directory handler ───────────────────
MIMEAPPS="$HOME/.config/mimeapps.list"
mkdir -p "$(dirname "$MIMEAPPS")"

# Ensure [Default Applications] section exists and contains the Thunar entry
if ! grep -q 'inode/directory=thunar.desktop' "$MIMEAPPS" 2>/dev/null; then
    if ! grep -q '\[Default Applications\]' "$MIMEAPPS" 2>/dev/null; then
        printf '[Default Applications]\n' >> "$MIMEAPPS"
    fi
    printf 'inode/directory=thunar.desktop\n' >> "$MIMEAPPS"
    ok "Thunar set as default directory handler in mimeapps.list."
else
    ok "Thunar MIME entry already present."
fi

# ── ~/.bashrc additions ────────────────────────────────────────────────────────
BASHRC="$HOME/.bashrc"

if ! grep -q '# ── Arch setup additions' "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'BASHEOF'

# ── Arch setup additions ──────────────────────────────────────────────────────

# Starship prompt
eval "$(starship init bash)"

# eza as ls replacement
alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --group-directories-first --git'
alias lt='eza --tree --icons --level=2'

# System maintenance — update everything in one shot
alias maintain='paru -Syu --noconfirm && flatpak update -y && sudo fwupdmgr get-updates && sudo fwupdmgr update && paru -Sc --noconfirm'

# Quick health check
alias locks='~/.local/bin/check_locks.sh'

# PATH
export PATH="$HOME/.local/bin:$PATH"

BASHEOF
    ok "Aliases + PATH added to ~/.bashrc."
else
    ok "~/.bashrc additions already present — skipping."
fi

# ══════════════════════════════════════════════════════════════════════════════
step "14/15  Local scripts"
# ══════════════════════════════════════════════════════════════════════════════

# ── pacman_updates.sh — Waybar custom/updates module ─────────────────────────
# Output format: "⟳ 3 +2 AUR" or empty string when up to date
cat > "$LOCAL_BIN/pacman_updates.sh" << 'EOF'
#!/usr/bin/env bash
# pacman_updates.sh — update count for Waybar custom/updates module
# Requires: pacman-contrib (checkupdates), paru
# Returns JSON tooltip-compatible output for Waybar.

PACMAN=$(checkupdates 2>/dev/null | wc -l)
AUR=$(paru -Qu --aur 2>/dev/null | wc -l)
TOTAL=$((PACMAN + AUR))

if [[ "$TOTAL" -eq 0 ]]; then
    echo ""
else
    echo "⟳ ${PACMAN}+${AUR} AUR"
fi
EOF
chmod +x "$LOCAL_BIN/pacman_updates.sh"
ok "pacman_updates.sh → $LOCAL_BIN/pacman_updates.sh"

# ── check_locks.sh — system health snapshot (replaces Fedora dnf version check) ──
cat > "$LOCAL_BIN/check_locks.sh" << 'EOF'
#!/usr/bin/env bash
# check_locks.sh — Arch system health snapshot
# Replaces the old dnf versionlock checker.
# Run manually or via: alias locks='~/.local/bin/check_locks.sh'

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "\n${BOLD}── Arch System Health ──────────────────────────────────────${NC}"

# — reflector last run ─────────────────────────────────────────────
RLOG="/var/log/reflector/reflector.log"
if [[ -f "$RLOG" ]]; then
    RDATE=$(stat -c %y "$RLOG" | cut -d. -f1)
    echo -e "  reflector last run : $RDATE"
else
    echo -e "${YELLOW}  reflector log not found — run: sudo reflector --save /etc/pacman.d/mirrorlist${NC}"
fi

# — pacman cache size ──────────────────────────────────────────────
CACHE=$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1 || echo "unknown")
echo -e "  pacman cache       : $CACHE  (clean with: paru -Sc)"

# — pending updates ────────────────────────────────────────────────
PACMAN_U=$(checkupdates 2>/dev/null | wc -l)
AUR_U=$(paru -Qu --aur 2>/dev/null | wc -l)
TOTAL_U=$((PACMAN_U + AUR_U))

if [[ "$TOTAL_U" -eq 0 ]]; then
    echo -e "${GREEN}  updates            : up to date${NC}"
else
    echo -e "${YELLOW}  updates            : $PACMAN_U pacman, $AUR_U AUR pending — run: maintain${NC}"
fi

# — AppArmor ───────────────────────────────────────────────────────
if systemctl is-active --quiet apparmor 2>/dev/null; then
    AA_PROF=$(sudo aa-status --json 2>/dev/null | jq '.profiles | length' 2>/dev/null || echo "?")
    echo -e "${GREEN}  AppArmor           : active ($AA_PROF profiles)${NC}"
else
    echo -e "${RED}  AppArmor           : INACTIVE — run: sudo systemctl start apparmor${NC}"
fi

# — ufw ────────────────────────────────────────────────────────────
UFW_OUT=$(sudo ufw status 2>/dev/null | head -1)
if echo "$UFW_OUT" | grep -qi 'active'; then
    echo -e "${GREEN}  ufw                : active${NC}"
else
    echo -e "${RED}  ufw                : INACTIVE — run: sudo ufw enable${NC}"
fi

# — Snapper ────────────────────────────────────────────────────────
SNAP_COUNT=$(sudo snapper -c root list 2>/dev/null | grep -c 'pre\|post\|single' || echo 0)
echo -e "  snapshots          : $SNAP_COUNT (root config)"

echo -e "${BOLD}─────────────────────────────────────────────────────────────${NC}\n"
EOF
chmod +x "$LOCAL_BIN/check_locks.sh"
ok "check_locks.sh → $LOCAL_BIN/check_locks.sh"

# ── battery_notify.sh placeholder ─────────────────────────────────────────────
# Referenced in DECISIONS.md spawn-at-startup list. Create stub if not in dotfiles yet.
if [[ ! -f "$LOCAL_BIN/battery_notify.sh" ]]; then
    cat > "$LOCAL_BIN/battery_notify.sh" << 'EOF'
#!/usr/bin/env bash
# battery_notify.sh — low battery notification daemon
# Sends a desktop notification when battery drops below threshold.
# Runs as spawn-at-startup in niri config.kdl

THRESHOLD=15
NOTIFIED=false

while true; do
    LEVEL=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100)
    STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")

    if [[ "$LEVEL" -le "$THRESHOLD" && "$STATUS" == "Discharging" && "$NOTIFIED" == "false" ]]; then
        notify-send -u critical -i battery-low "Battery Low" "Battery at ${LEVEL}%. Plug in."
        NOTIFIED=true
    fi

    if [[ "$STATUS" == "Charging" ]]; then
        NOTIFIED=false
    fi

    sleep 60
done
EOF
    chmod +x "$LOCAL_BIN/battery_notify.sh"
    ok "battery_notify.sh stub created → $LOCAL_BIN/battery_notify.sh"
fi

# ── fix_webcam.sh placeholder ──────────────────────────────────────────────────
# Referenced in DECISIONS.md spawn-at-startup list.
if [[ ! -f "$LOCAL_BIN/fix_webcam.sh" ]]; then
    cat > "$LOCAL_BIN/fix_webcam.sh" << 'EOF'
#!/usr/bin/env bash
# fix_webcam.sh — webcam quirk fix at session startup
# ThinkPad P14s Gen 4 AMD: add any webcam init steps here.
# Currently a stub — no known issue yet.
exit 0
EOF
    chmod +x "$LOCAL_BIN/fix_webcam.sh"
    ok "fix_webcam.sh stub created → $LOCAL_BIN/fix_webcam.sh"
fi

# ══════════════════════════════════════════════════════════════════════════════
step "15/15  Final GRUB regeneration"
# ══════════════════════════════════════════════════════════════════════════════
# Run again now that os-prober can also see the mounted DATA partition
# and Windows OS partition correctly.

sudo grub-mkconfig -o /boot/grub/grub.cfg
ok "GRUB config regenerated (final pass)."

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  arch-setup.sh complete.${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BOLD}  Verify now (before reboot):${NC}"
echo -e "  ${CYAN}sudo aa-status${NC}           — AppArmor profiles loaded"
echo -e "  ${CYAN}sudo ufw status${NC}          — firewall active"
echo -e "  ${CYAN}cat /etc/fstab${NC}           — DATA partition entry present"
echo -e "  ${CYAN}systemctl status wifi-resume${NC} — service enabled"
echo ""
echo -e "${BOLD}  After reboot:${NC}"
echo -e "  1. GRUB menu shows ${BOLD}both Arch Linux and Windows${NC}"
echo -e "  2. ${CYAN}source ~/.bashrc${NC}       — load aliases incl. 'maintain'"
echo -e "  3. ${CYAN}fprintd-enroll manokel${NC} — fingerprint setup (in graphical session)"
echo -e "  4. ${CYAN}~/.local/bin/check_locks.sh${NC}  — system health snapshot"
echo -e "  5. Switch dotfiles remote to SSH once key is configured:"
echo -e "     ${CYAN}git -C ~/dotfiles remote set-url origin $DOTFILES_REPO_SSH${NC}"
echo ""
echo -e "${BOLD}  Next step:${NC} Phase 1 Chat A → archinstall.json"
echo -e "  Then:      Phase 2 Chat C → niri/config.kdl"
echo ""
