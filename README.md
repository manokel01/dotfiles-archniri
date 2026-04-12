# System Architecture & Configuration Guide

**Hardware:** Lenovo ThinkPad P14s Gen 4 (AMD Ryzen 7 Pro 7840U, 64GB RAM, 2TB NVMe)  
**Display:** 1920x1200 400-nit Matte IPS (eDP-1) + LG HDR 4K 3840x2160 (DP-2)  
**Peripherals:** NuPhy Air75 V3 (2.4G/BT), Logitech MX Master 3S (BT)  
**OS:** Arch Linux  
**Compositor:** Niri (Scrollable-tiling Wayland)  

---

## 1. Design Philosophy

This system is configured for a strictly professional, minimalist workflow with zero visual clutter.

- **Visuals:** Nord colour palette, zero rounded corners, zero shadows, zero blur. Static hardcoded palette — no dynamic theming.
- **Performance:** Aggressive idle management (swayidle dual-path), Btrfs with zstd compression and noatime, zram swap, journald hard-filtering. No polling scripts where signals suffice.
- **Control:** Dotfiles managed via a Git repository (`~/dotfiles`) synced to GitHub, deployed via **GNU Stow**. UI-critical configs (niri, waybar) remain physical files in `~/.config/` to enable live hot-reloading without stow conflicts. The `void` sync script ingests them into the vault.

---

## 2. Core Stack & Tools

- **Compositor:** Niri 25.11 (scrollable-tiling, Wayland-native, Rust-based)
- **Session Manager:** UWSM — compositor launched via `uwsm start niri-session`
- **Dotfile Management:** Git repository at `~/dotfiles` synced to GitHub, deployed via **GNU Stow** and custom `void` sync logic
- **Terminal:** Kitty (Nord, JetBrainsMono Light 12pt, ligatures enabled)
- **Text Editing:** micro (primary terminal editor, CUA keybinds)
- **Status Bar:** Waybar (top bar, Nord theme, signal-based language module)
- **App Launcher:** Vicinae (Rust-based, Wayland-native, replaces Walker)
- **Window Switcher:** niri-switch (Alt+Tab native for Niri)
- **Screen Lock:** gtklock (GTK-based, Nord CSS, userinfo + powerbar + dpms modules)
- **Idle Management:** swayidle (dual-path battery/AC logic via `/sys/class/power_supply/AC/online`)
- **Wallpaper:** swaybg
- **Notification Daemon:** swaync
- **System TUIs:** btop, yazi, wiremix
- **Browser:** Firefox (daily) + Brave (Chromium compatibility)
- **Clipboard Manager:** cliphist (accessible via Vicinae clipboard history)
- **Screenshot:** Grim + Slurp + wl-clipboard
- **GTK Management:** nwg-look (Nordic GTK theme, Papirus-Dark icons)
- **Cloud/Hardware Sync:** Rclone (guarded two-way bisync)
- **Secret Management:** Bitwarden via rbw CLI
- **AUR Helper:** paru

### File Management

- **GUI File Manager:** Thunar — lightweight, no KDE/Qt dependencies
- **Terminal File Manager:** Yazi
- **MIME Association:** Hard-coded in `~/.config/mimeapps.list` (`inode/directory=thunar.desktop`)
- **Portal:** xdg-desktop-portal-gtk (compatible with Thunar)

---

## 3. Kernel, Filesystem & Hardware Tuning

### Filesystem (Btrfs)
`/etc/fstab` configured with `noatime`, `compress=zstd`, and `discard=async` to reduce SSD wear.

**Partition Layout:**

| Partition | Size | Filesystem | Purpose |
|-----------|------|------------|---------|
| nvme0n1p1 | 200M | vfat | ESP — shared with Windows, DO NOT FORMAT |
| nvme0n1p2 | 16M | — | Windows reserved |
| nvme0n1p3 | 202.9G | ntfs | Windows OS |
| nvme0n1p4 | 195.3G | ntfs3 | DATA — shared read/write across dual-boot |
| nvme0n1p5 | 754M | ntfs | Windows Recovery |
| nvme0n1p6 | 1.4T | Btrfs | Arch Linux root |

**Btrfs subvolumes:** @, @home, @snapshots, @log, @cache

### Memory Management
- **8GB ZRAM** via zram-generator (no swap partition)
- 64GB RAM pool prioritised — no swappiness tuning needed

### Hardware Quirks
- **Wi-Fi (Qualcomm QCNFA765 / ath11k_pci):** Kernel 6.19+ handles s2idle suspend natively. The `wifi-resume.service` workaround is no longer required and has been disabled.
- **Brightness:** `brightnessctl` used for kernel-level brightness control. `swayosd-client` displays the OSD bar after each change.
- **Mic LED (F4):** ThinkPad F4 LED does not respond to software mute state by default. Controlled via `~/.local/bin/mic-toggle.sh` which writes to `/sys/class/leds/platform::micmute/brightness` via a sudoers rule.
- **Fingerprint:** `fprintd` — enrolled both index fingers. D-Bus activated (no systemd enable needed).
- **GPU:** AMD Radeon 780M. `LIBVA_DRIVER_NAME=radeonsi`, `VDPAU_DRIVER=radeonsi`.

### Journald Hard-Filter
Drop-in at `/etc/systemd/journald.conf.d/`: `MaxLevelStore=warning`, `SystemMaxUse=100M`. Drops 95% of routine OS logging to keep NVMe in deep sleep states.

### Adaptive Idle (swayidle)
Dual-path power sensing via `/sys/class/power_supply/AC/online`:
- **Battery path:** 150s dim → 180s lock → 210s DPMS → 900s suspend
- **AC path:** 540s dim → 600s lock → 660s DPMS → no suspend

---

## 4. Disaster Recovery (Snapper)

System backups managed via **Snapper** on Btrfs.

- **Config:** `root` covering `/` with NUMBER_LIMIT=10
- **Automated snapshots:** Pre- and post-transaction snapshots for every `pacman` / `paru` operation via `snap-pac`
- **Manual snapshots:** The `void` script triggers `sudo snapper create` before any Git push
- **Rollbacks:** `snapper -c root list` then `snapper -c root rollback N`

---

## 5. UI & Theming

- **Colour Palette:** Nord (static hardcoded — no Wallust/awww)
- **GTK Theme:** Nordic (via nwg-look)
- **Icon Theme:** Papirus-Dark (with Nord folder colours via papirus-folders)
- **Terminal Font:** JetBrainsMono Nerd Font Light, 12pt, ligatures enabled
- **Waybar Font:** JetBrainsMono Nerd Font, 13px
- **Cursor:** Adwaita, 24px
- **Niri Aesthetics:** Gaps 0, no border rounding, no shadows, no blur. Inactive windows at 0.9 opacity.
- **Wallpaper:** ramen illustration via swaybg (`-m fill`)

### Nord Colour Reference

| Name | Hex | Primary Usage |
|------|-----|--------------|
| nord0 | #2E3440 | Background |
| nord1 | #3B4252 | Surfaces, selection |
| nord3 | #4C566A | Muted text, borders |
| nord4 | #D8DEE9 | Primary foreground |
| nord8 | #88C0D0 | Cyan — active elements, clock |
| nord9 | #81A1C1 | Blue — directory, language |
| nord11 | #BF616A | Red — errors, poweroff |
| nord13 | #EBCB8B | Yellow — warnings, reboot |
| nord14 | #A3BE8C | Green — success, wifi, battery |
| nord15 | #B48EAD | Purple — audio |

---

## 6. Keybindings

**Modifier Key:** Physical Alt key (1st left of spacebar) — acts as Super/MOD via xkb `altwin:swap_lalt_lwin`  
**Physical Win key** (2nd left of spacebar) — acts as Alt

### System & Shortcuts

| Action | Shortcut | Notes |
|--------|----------|-------|
| App Launcher | `MOD + A` | Vicinae toggle |
| Terminal | `MOD + Return` | Kitty |
| File Manager (GUI) | `MOD + E` | Thunar |
| File Manager (TUI) | `MOD + Alt + E` | Yazi |
| Browser | `MOD + B` | Firefox |
| Lock Screen | `MOD + Shift + Q` | gtklock (forces US layout first) |
| Screenshot (area) | `MOD + S` | Grim + Slurp |
| Screenshot (screen) | `MOD + Shift + S` | Full screen |
| Screenshot (window) | `MOD + Ctrl + S` | Focused window |
| Shortcuts overlay | `MOD + Shift + Escape` | Niri hotkey overlay |
| Overview | `MOD + Escape` | Niri overview mode |
| Close window | `MOD + Q` | |
| Reload niri config | `MOD + Shift + R` | `niri msg action load-config-file` |
| Restart Waybar | `MOD + Shift + W` | `killall waybar; waybar` |
| Language switch | `MOD + Space` | US ↔ GR + Waybar signal |
| Window switcher | `Alt + Tab` | niri-switch |

### Window Management

| Action | Shortcut |
|--------|----------|
| Focus left/right | `MOD + H/L` or `MOD + ←/→` |
| Focus workspace up/down | `MOD + K/J` or `MOD + ↑/↓` |
| Move column left/right | `MOD + Shift + H/L` |
| Move to workspace | `MOD + Shift + K/J` |
| Focus monitor | `MOD + Ctrl + H/J/K/L` |
| Move to monitor | `MOD + Shift + Ctrl + H/J/K/L` |
| Toggle floating | `MOD + T` |
| Fullscreen | `MOD + F` |
| Maximize column | `MOD + M` |
| Center column | `MOD + C` |
| Switch workspace 1-9 | `MOD + 1-9` |
| Move to workspace 1-9 | `MOD + Shift + 1-9` |

### Media Keys (all work when locked)

| Action | Key |
|--------|-----|
| Volume up/down | `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` |
| Mute | `XF86AudioMute` |
| Mic mute + LED | `XF86AudioMicMute` (via mic-toggle.sh) |
| Brightness up/down | `XF86MonBrightnessUp` / `XF86MonBrightnessDown` |
| Play/Pause | `XF86AudioPlay` / `XF86AudioPause` |
| Next/Prev | `XF86AudioNext` / `XF86AudioPrev` |

---

## 7. Critical System Quirks

1. **Niri Session Launch:** Must use `uwsm start niri-session` — NOT `uwsm start niri`. The `niri-session` binary correctly exports `WAYLAND_DISPLAY` to the systemd activation environment within UWSM's timeout window.

2. **Keyboard Layout:** xkb `altwin:swap_lalt_lwin` swaps physical Alt and Win keys in software. NuPhy Air75 V3 firmware swap must be **disabled** via nuphy.io — otherwise the double-swap undoes itself and the NuPhy behaves as unswapped. Greek layout uses `gr` (not `el`) in xkb.

3. **Waybar Language Module:** Uses signal-based update (`pkill -SIGRTMIN+1 waybar`) — not polling. `interval: "once"` + signal avoids the 1-second polling overhead.

4. **gtklock Powerbar Icons:** The powerbar module icons (`system-shutdown-symbolic`, `system-reboot-symbolic`, `weather-clear-night-symbolic`) fail to render from the GTK icon theme at lock time. Workaround: buttons are colour-coded via CSS (red=shutdown, yellow=reboot, blue=suspend). Functional but visually imperfect.

5. **Brightness Backend:** `swayosd-client --brightness` does not detect `amdgpu_bl1` automatically. Brightness is set via `brightnessctl` and the OSD is triggered separately via `swayosd-client --brightness raise/lower` (which shows the bar without actually changing brightness again — harmless).

6. **Mic LED Control:** `/sys/class/leds/platform::micmute/brightness` requires root write access. Handled via a sudoers drop-in (`/etc/sudoers.d/micmute`) granting `manokel ALL=(ALL) NOPASSWD: /usr/bin/tee`.

7. **Decoupled UI Files:** `~/.config/niri/config.kdl` and `~/.config/waybar/` MUST remain physical directories — NOT Stow symlinks. This is required for `git_sync_status.sh` to execute diff checks and for Waybar to hot-reload CSS without symlink resolution issues.

8. **Absolute Path Binding:** Niri keybinds using `spawn-sh` must reference scripts by name only if `~/.local/bin` is in `$PATH`. Otherwise use absolute paths (`/home/manokel/.local/bin/script.sh`).

9. **Auto-login to Niri:** `~/.bash_profile` contains: `if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then exec uwsm start niri-session; fi`. No display manager installed — login at TTY1 launches Niri automatically.

---

## 8. Maintenance Workflow (The "Void" Sync)

Dotfiles are managed via a centralised repository at `~/dotfiles/` pushed to GitHub (`origin main`). The system uses a **Hybrid Deployment Strategy** to balance stability with live UI experimentation.

### The Hybrid Logic

- **Stow-Managed (Stable):** Core applications and scripts — `micro`, `kitty`, `starship`, all scripts in `~/.local/bin/`. These reside permanently in the vault and are symlinked to the system.
- **Decoupled (Experimental):** UI-critical configs for `niri` (`config.kdl`), `waybar` (`config.jsonc`, `style.css`). These remain **physical files** in `~/.config/`. The `void` script uses an explicit `UI_TARGETS` array to pull these into the vault during sync.

### The Sync Process (`void` script)

1. **Live Audit:** `git_sync_status.sh` runs a `diff` between physical UI files (niri, waybar) and the vault. If they differ, the Waybar Git icon alerts.
2. **Pre-sync Snapshot:** `sudo snapper create` captures a Btrfs snapshot before committing.
3. **Vault Ingestion:** `void` copies physical UI and script changes into `~/dotfiles/`, ignoring symlinks.
4. **GitHub Serialisation:** Changes are staged, committed, and pushed. A `SIGUSR2` signal resets the Waybar Git icon to Green (Synced).

### UI_TARGETS Array (needs update from Hyprland paths)
The `void` script `UI_TARGETS` array must be updated to reference Niri/Arch paths:
- `~/.config/niri/config.kdl`
- `~/.config/waybar/config.jsonc`
- `~/.config/waybar/style.css`
- `~/.config/swayidle/config`
- `~/.config/kanshi/config`
- `~/.config/gtklock/style.css`
- `~/.config/kitty/kitty.conf`
- `~/.config/starship.toml`

---

## 9. Data Integrity & Cloud Sync

The local data directory (`/mnt/data`) is the Ground Truth, syncing bidirectionally with Google Drive via Rclone bisync.

- **Silent Auditor:** A systemd user-timer triggers `rclone_auditor.sh` daily
- **Safe Auto-Commit:** Additions-only → syncs invisibly
- **Guarded Interrupt:** Deletions/updates detected → aborts, drops `~/.rclone_pending_review`
- **UI Feedback:** Waybar `custom/rclone` module: Green (Idle), Red (Active), Blue (Pending Review), Yellow (Error)
- **Manual Approval:** Clicking Blue icon launches `rclone_sync.sh` in a floating Kitty window
- **Hard Resync:** Right-click launches `rclone_resync.sh` (`--resync --resilient`) to resolve split-brain states

---

## 10. Secrets & Biometrics

- **Stack:** `rbw` (Rust CLI) + Vicinae (clipboard/bitwarden integration) + `pinentry-gnome3`
- **Biometrics:** `fprintd` — both index fingers enrolled. Integrated with PAM for fingerprint unlock
- **Workflow:** Vicinae clipboard history surfaces recent copies; `rbw` CLI used for programmatic access
- **Sync:** `rbw sync` — fully functional offline for read access

---

## 11. Installation & Recovery

### Fresh Install (Arch)

```bash
# 1. Boot Arch live USB, enable SSH
passwd root && systemctl start sshd

# 2. Download and run pre-archinstall.sh (partitioning + Btrfs setup)
curl -O https://raw.githubusercontent.com/manokel01/dotfiles-archniri/main/pre-archinstall.sh
SKIP_PARTITIONING=1 bash pre-archinstall.sh  # if partitions already created via cgdisk

# 3. Set passwords in archinstall.json, then run archinstall
curl -O https://raw.githubusercontent.com/manokel01/dotfiles-archniri/main/archinstall.json
# Edit passwords, then:
archinstall --config archinstall.json

# 4. After reboot, run arch-setup.sh as manokel
bash <(curl -s https://raw.githubusercontent.com/manokel01/dotfiles-archniri/main/arch-setup.sh)
```

### Repo Structure

```
dotfiles-archniri/
├── archinstall.json                                 ← archinstall config
├── pre-archinstall.sh                               ← Btrfs partition + mount setup
├── arch-setup.sh                                    ← post-install automation (15 steps)
├── niri/.config/niri/config.kdl                     ← Niri compositor config
├── kanshi/.config/kanshi/config                     ← monitor profiles (clamshell etc.)
├── swayidle/.config/swayidle/config                 ← idle management
├── waybar/.config/waybar/config.jsonc               ← Waybar modules
├── waybar/.config/waybar/style.css                  ← Waybar Nord theme
├── kitty/.config/kitty/kitty.conf                   ← terminal config
├── starship/.config/starship.toml                   ← shell prompt (Nord, Pure style)
├── gtklock/.config/gtklock/style.css                ← lock screen Nord theme
├── gtklock/.config/gtklock/config.ini               ← lock screen modules
├── scripts/.local/bin/                              ← all custom scripts
│   ├── mic-toggle.sh                                ← F4 mic mute + LED + OSD
│   ├── toggle-layout.sh                             ← Waybar language indicator
│   ├── pacman_updates.sh                            ← Waybar updates module
│   ├── check_locks.sh                               ← system health snapshot
│   └── battery_notify.sh                            ← low battery alert
└── systemd-user/.config/systemd/user/
    └── gtklock.service                              ← lock.target integration
```

### Key Post-Install Commands

```bash
# Verify security
sudo aa-status          # AppArmor: 161+ profiles loaded
sudo ufw status         # Firewall: active

# Start Niri session
uwsm start niri-session

# Stow dotfiles
cd ~/dotfiles && stow niri kanshi swayidle waybar kitty starship scripts systemd-user

# Check system health
~/.local/bin/check_locks.sh

# Update everything
maintain  # alias: paru -Syu + flatpak update + fwupdmgr update + paru -Sc
```
