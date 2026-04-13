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
- **App Launcher:** Vicinae (Rust-based, Wayland-native)
- **App Grid:** nwg-drawer (fullscreen app grid, triggered from Waybar)
- **Window Switcher:** niri-switch (Alt+Tab native for Niri)
- **Screen Lock:** gtklock (GTK-based, Nord CSS, userinfo + powerbar + dpms modules)
- **Power Menu:** wlogout (lock/logout/suspend/reboot/shutdown overlay)
- **Idle Management:** swayidle (dual-path battery/AC logic via `/sys/class/power_supply/AC/online`)
- **Wallpaper:** swaybg
- **Notification Daemon:** swaync
- **System TUIs:** btop, yazi, wiremix
- **Browser:** Firefox (daily, hardware-accelerated) + Brave (Chromium/X.com PWA)
- **Clipboard Manager:** cliphist (accessible via Vicinae clipboard history)
- **Screenshot:** Grim + Slurp + wl-clipboard
- **Archive Manager:** file-roller (GTK, Thunar right-click integration)
- **External Drive Mounting:** udiskie (tray icon, auto-mount on plug)
- **GTK Management:** nwg-look (Nordic GTK theme, Papirus-Dark icons)
- **Cloud/Hardware Sync:** Rclone (guarded two-way bisync)
- **Secret Management:** Bitwarden via rbw CLI
- **Power Profiles:** power-profiles-daemon (power-saver / balanced / performance)
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
- **Wi-Fi (Qualcomm QCNFA765 / ath11k_pci):** Known speed-drop bug — download collapses to ~3 Mbps after extended use or suspend cycles while upload remains normal. Root cause: AMPDU aggregation session bug. Fix merged in Linux 7.0 (released April 12, 2026 — pending Arch package). Interim workaround: `wifi-fix` alias in `~/.bashrc` restarts NetworkManager.
- **Brightness:** `brightnessctl` for kernel-level control + `swayosd-client` for OSD. External monitor brightness via DDC (`ddcutil setvcp 10 <value>`) — too slow for interactive keybind use, use monitor physical buttons. Brightness keys send DDC command in parallel via `--noverify` flag.
- **Mic LED (F4):** Controlled via `~/.local/bin/mic-toggle.sh` writing to `/sys/class/leds/platform::micmute/brightness` via sudoers rule.
- **Fingerprint:** `fprintd` — enrolled both index fingers. D-Bus activated (no systemd enable needed).
- **GPU:** AMD Radeon 780M. `LIBVA_DRIVER_NAME=radeonsi`, `VDPAU_DRIVER=radeonsi`.
- **NuPhy Keyboard:** Firmware Alt/Win swap must be **disabled** via nuphy.io. Software xkb `altwin:swap_lalt_lwin` handles the swap for both keyboards consistently.

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
- **Firefox:** Nord addon installed. Hardware acceleration: WebRender + VA-API enabled.
- **Brave:** Nord theme applied. Hardware acceleration: VA-API + Vulkan + Skia Graphite via `brave://flags`. X.com installed as PWA (dedicated window).

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

### Waybar Clickable Modules

| Module | Left Click | Right Click |
|--------|-----------|-------------|
| App Grid icon | nwg-drawer | — |
| Git sync icon | void (commit/push) | — |
| Power profile | cycle profiles | — |
| Rclone | rclone_sync.sh | rclone_resync.sh |
| Audio | wiremix TUI | — |
| Power icon | wlogout overlay | — |
| Updates | paru -Syu | — |

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

1. **Niri Session Launch:** Must use `uwsm start niri-session` — NOT `uwsm start niri`.

2. **Keyboard Layout:** xkb `altwin:swap_lalt_lwin` swaps physical Alt and Win keys. NuPhy firmware swap must be **disabled** via nuphy.io. Greek layout uses `gr` (not `el`) in xkb.

3. **Waybar Language Module:** Signal-based update (`pkill -SIGRTMIN+1 waybar`). `interval: 2` for polling fallback.

4. **gtklock Powerbar Icons:** Icons fail to render at lock time. CSS colour workaround: red=shutdown, yellow=reboot, blue=suspend.

5. **Brightness + External Monitor:** Brightness keys control internal (brightnessctl) and external (ddcutil `--noverify`) in parallel. OSD reflects internal display only. DDC too slow for dedicated keybind.

6. **Wi-Fi Speed Drop:** `wifi-fix` alias restarts NetworkManager. Permanent fix in Linux 7.0 — run `paru -Syu` when kernel 7.0 lands in Arch repos.

7. **Mic LED Control:** Sudoers drop-in required: `manokel ALL=(ALL) NOPASSWD: /usr/bin/tee`.

8. **Decoupled UI Files:** `~/.config/niri/config.kdl` and `~/.config/waybar/` MUST remain physical files — NOT Stow symlinks.

9. **Auto-login:** `~/.bash_profile` launches `uwsm start niri-session` on TTY1 automatically.

10. **Power Profile:** Waybar power profile icon cycles power-saver → balanced → performance via `powerprofilesctl` + `notify-send`.

11. **X.com PWA:** Installed in Brave via `⋮` → More tools → Create shortcut → Open as window. Isolated process, no tab overhead.

---

## 8. Maintenance Workflow (The "Void" Sync)

### The Hybrid Logic

- **Stow-Managed:** `kitty`, `starship`, `gtklock`, `vicinae`, `wlogout`, all scripts in `~/.local/bin/`
- **Decoupled:** `niri/config.kdl`, `waybar/config.jsonc`, `waybar/style.css`, `swayidle/config`, `kanshi/config`, `gtklock/style.css`, `kitty/kitty.conf`, `starship.toml`

### The Sync Process

1. Waybar Git icon shows drift when live files differ from vault
2. Click Git icon → opens `void` in floating Kitty window
3. `void` copies decoupled files into vault, stages, prompts for commit message, pushes
4. Waybar Git icon resets to Green on success

---

## 9. Data Integrity & Cloud Sync

- **Rclone bisync:** `/mnt/data` ↔ Google Drive
- **Waybar `custom/rclone`:** Green (Idle), Red (Active), Blue (Pending Review), Yellow (Error)
- **Manual Approval:** Click Blue → `rclone_sync.sh` in floating Kitty window
- **Hard Resync:** Right-click → `rclone_resync.sh` (`--resync --resilient`)

---

## 10. Secrets & Biometrics

- **Stack:** `rbw` (Rust CLI) + Vicinae clipboard + `pinentry-gnome3`
- **Biometrics:** `fprintd` — both index fingers enrolled, PAM integrated
- **Sync:** `rbw sync` — functional offline for read access

---

## 11. Installation & Recovery

### Fresh Install (Arch)

```bash
# 1. Boot Arch live USB, enable SSH
passwd root && systemctl start sshd

# 2. Run pre-archinstall.sh
curl -O https://raw.githubusercontent.com/manokel01/dotfiles-archniri/main/pre-archinstall.sh
SKIP_PARTITIONING=1 bash pre-archinstall.sh

# 3. Run archinstall
curl -O https://raw.githubusercontent.com/manokel01/dotfiles-archniri/main/archinstall.json
archinstall --config archinstall.json

# 4. Run arch-setup.sh after reboot
bash <(curl -s https://raw.githubusercontent.com/manokel01/dotfiles-archniri/main/arch-setup.sh)
```

### Repo Structure

```
dotfiles-archniri/
├── archinstall.json
├── pre-archinstall.sh
├── arch-setup.sh
├── niri/.config/niri/config.kdl
├── kanshi/.config/kanshi/config
├── swayidle/.config/swayidle/config
├── waybar/.config/waybar/config.jsonc + style.css
├── kitty/.config/kitty/kitty.conf
├── starship/.config/starship.toml
├── gtklock/.config/gtklock/style.css + config.ini
├── vicinae/.config/vicinae/config.json
├── wlogout/.config/wlogout/layout + style.css
├── scripts/.local/bin/
│   ├── mic-toggle.sh          ← F4 mic mute + LED + OSD
│   ├── toggle-layout.sh       ← Waybar language indicator
│   ├── pacman_updates.sh      ← Waybar updates module
│   ├── git_sync_status.sh     ← Waybar git drift detector
│   ├── void                   ← dotfiles sync script
│   ├── power_status.sh        ← Waybar power profile icon
│   ├── power_profile.sh       ← power profile cycler
│   ├── wlogout-launch.sh      ← Niri-aware wlogout launcher
│   ├── check_locks.sh         ← system health snapshot
│   └── battery_notify.sh      ← low battery alert
└── systemd-user/.config/systemd/user/gtklock.service
```

### Stow Deploy

```bash
cd ~/dotfiles
stow niri kanshi swayidle waybar kitty starship gtklock vicinae wlogout scripts systemd-user
```

### Key Commands

```bash
sudo aa-status              # AppArmor: 161+ profiles loaded
sudo ufw status             # Firewall: active
maintain                    # paru -Syu + flatpak + fwupdmgr + paru -Sc
wifi-fix                    # restore Wi-Fi speed if dropped
powerprofilesctl get        # check current power profile
snapper -c root list        # list Btrfs snapshots
```
