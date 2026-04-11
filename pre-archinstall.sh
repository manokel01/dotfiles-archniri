#!/usr/bin/env bash
# ============================================================================
# pre-archinstall.sh
# ThinkPad P14s Gen 4 AMD — Arch Linux Phase 1
#
# Run this FIRST from the live USB (via SSH from MacBook), BEFORE archinstall.
# It handles everything archinstall cannot: deletes the Fedora partitions,
# creates the new Btrfs partition, formats it, creates subvolumes, and mounts
# the full tree at /mnt so archinstall can use pre_mounted_config mode.
#
# Usage:
#   curl -O https://raw.githubusercontent.com/manokel01/dotfiles-archniri/main/pre-archinstall.sh
#   bash pre-archinstall.sh
# ============================================================================

set -euo pipefail

DISK="/dev/nvme0n1"
ESP="${DISK}p1"        # DO NOT format — shared with Windows
ROOT_PART="${DISK}p6"  # Will be created fresh
BTRFS_LABEL="arch"
BTRFS_OPTS="compress=zstd,noatime"

RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
CYN='\033[0;36m'
NC='\033[0m'

header() { echo -e "\n${CYN}▶ $*${NC}"; }
ok()     { echo -e "  ${GRN}✓${NC} $*"; }
warn()   { echo -e "  ${YEL}⚠${NC} $*"; }
die()    { echo -e "  ${RED}✗ FATAL: $*${NC}"; exit 1; }

echo -e "${CYN}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║  pre-archinstall.sh — ThinkPad P14s Gen 4 AMD         ║"
echo "║  Fedora → Arch Linux, Phase 1                         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── SANITY CHECKS ─────────────────────────────────────────────────────────────
header "Sanity checks"

[[ -b "$DISK" ]] || die "$DISK not found. Are you on the live ISO?"
command -v sgdisk >/dev/null || die "sgdisk not found. Run: pacman -Sy gptfdisk"
command -v mkfs.btrfs >/dev/null || die "mkfs.btrfs not found. Run: pacman -Sy btrfs-progs"

ok "Disk $DISK present"
ok "sgdisk and mkfs.btrfs available"

# ── STEP 0: PHYSICAL LAYOUT ANALYSIS ─────────────────────────────────────────
header "STEP 0 — Physical disk layout (read carefully)"

echo ""
echo "  Partition table with physical sector positions:"
parted "$DISK" unit GiB print free
echo ""

cat <<'LAYOUT_NOTE'
  ┌─ What to look for ──────────────────────────────────────────────────────┐
  │                                                                          │
  │  After the DATA shrink, there is ~741 GiB of freed space somewhere.    │
  │  The critical question: where is it physically, relative to p5?         │
  │                                                                          │
  │  SCENARIO A (likely on ThinkPad OEM):                                   │
  │    Physical order: p1 p2 p3 p5(Recovery) p4(DATA) [741G free] p6 p7    │
  │    → After deleting p6+p7, the 741G and 659G are CONTIGUOUS             │
  │    → sgdisk -n 6:0:0 creates ONE ~1.4T partition ✓                     │
  │                                                                          │
  │  SCENARIO B (alternative layout):                                        │
  │    Physical order: p1 p2 p3 p4(DATA) [741G free] p5(Recovery) p6 p7   │
  │    → After deleting p6+p7, TWO separate free regions exist              │
  │    → sgdisk -n 6:0:0 creates ~741G partition (NOT the Fedora space)    │
  │    → In this case: use cgdisk (see SCENARIO B note below)               │
  │                                                                          │
  │  To distinguish: look at the Start column in the parted output above.   │
  │  If p5 Start < p4 Start → Scenario A. If p5 Start > p4 Start → B.     │
  └──────────────────────────────────────────────────────────────────────────┘

LAYOUT_NOTE

read -rp "  Press Enter once you've identified your scenario..."

# ── STEP 1: CONFIRMATION ──────────────────────────────────────────────────────
header "STEP 1 — Confirmation"

echo ""
echo "  About to PERMANENTLY DELETE:"
echo "    nvme0n1p6  (2G  — Fedora /boot)"
echo "    nvme0n1p7  (657G — Fedora root+home)"
echo ""
echo "  Will NOT be touched:"
echo "    nvme0n1p1  (200M — ESP, shared with Windows)"
echo "    nvme0n1p2  (16M  — Windows reserved)"
echo "    nvme0n1p3  (202.9G — Windows OS)"
echo "    nvme0n1p4  (195.3G — DATA)"
echo "    nvme0n1p5  (754M — Windows Recovery)"
echo ""
warn "If you are in SCENARIO B (see above), stop here and use cgdisk manually:"
warn "  cgdisk /dev/nvme0n1"
warn "  Delete p6 and p7, then create new p6 in the Fedora free space (after p5)."
warn "  Then re-run this script with SKIP_PARTITIONING=1 bash pre-archinstall.sh"
echo ""
read -rp "  Type 'delete-fedora' to confirm and continue: " CONFIRM

if [[ "$CONFIRM" != "delete-fedora" ]]; then
    echo "  Aborted — nothing was changed."
    exit 0
fi

# ── STEP 2: DELETE FEDORA PARTITIONS ─────────────────────────────────────────
if [[ "${SKIP_PARTITIONING:-0}" != "1" ]]; then

    header "STEP 2 — Deleting Fedora partitions"

    # Delete higher number first to avoid any table conflicts
    sgdisk -d 7 "$DISK"
    ok "nvme0n1p7 deleted"
    sgdisk -d 6 "$DISK"
    ok "nvme0n1p6 deleted"

    # ── STEP 3: CREATE NEW BTRFS PARTITION ───────────────────────────────────
    header "STEP 3 — Creating new Arch Linux partition (p6)"

    # -n 6:0:0   → partition 6, start at first available sector, end at last
    # -t 6:8300  → type: Linux filesystem
    # -c 6:...   → label
    sgdisk -n 6:0:0 -t 6:8300 -c 6:"arch-linux" "$DISK"
    ok "Partition table written"

    # Inform kernel
    partprobe "$DISK"
    sleep 2
    ok "Kernel notified of partition table change"

    echo ""
    echo "  New layout:"
    parted "$DISK" unit GiB print | grep -E "Number|p[1-7]|nvme"

else
    header "STEP 2+3 — Skipping partitioning (SKIP_PARTITIONING=1)"
    warn "Assuming you already created $ROOT_PART with cgdisk"
    [[ -b "$ROOT_PART" ]] || die "$ROOT_PART does not exist. Create it with cgdisk first."
fi

# ── STEP 4: FORMAT AS BTRFS ───────────────────────────────────────────────────
header "STEP 4 — Formatting $ROOT_PART as Btrfs"

mkfs.btrfs -L "$BTRFS_LABEL" -f "$ROOT_PART"
ok "Formatted as Btrfs, label='$BTRFS_LABEL'"

# ── STEP 5: CREATE SUBVOLUMES ─────────────────────────────────────────────────
header "STEP 5 — Creating Btrfs subvolumes"

mount "$ROOT_PART" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@cache

echo ""
btrfs subvolume list /mnt
umount /mnt
ok "Subvolumes created and root unmounted"

# ── STEP 6: MOUNT FULL TREE FOR ARCHINSTALL ───────────────────────────────────
header "STEP 6 — Mounting tree at /mnt for archinstall"

mount -o "${BTRFS_OPTS},subvol=@"          "$ROOT_PART" /mnt
mkdir -p /mnt/{boot/efi,home,.snapshots,var/log,var/cache}

mount -o "${BTRFS_OPTS},subvol=@home"      "$ROOT_PART" /mnt/home
mount -o "${BTRFS_OPTS},subvol=@snapshots" "$ROOT_PART" /mnt/.snapshots
mount -o "${BTRFS_OPTS},subvol=@log"       "$ROOT_PART" /mnt/var/log
mount -o "${BTRFS_OPTS},subvol=@cache"     "$ROOT_PART" /mnt/var/cache

echo ""
warn "Mounting ESP (nvme0n1p1) — DO NOT format, shared with Windows"
mount "$ESP" /mnt/boot/efi
ok "ESP mounted read-write (archinstall needs write access for GRUB)"

# ── VERIFY ────────────────────────────────────────────────────────────────────
header "Mount verification"

echo ""
findmnt --target /mnt --submounts -o TARGET,SOURCE,FSTYPE,OPTIONS
echo ""

# Final size report
ARCH_SIZE=$(df -h /mnt | awk 'NR==2{print $2}')
ok "Arch root partition size: $ARCH_SIZE"

echo -e "${GRN}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║  pre-archinstall.sh complete                          ║"
echo "║                                                        ║"
echo "║  Everything is mounted at /mnt.                       ║"
echo "║  Next steps:                                           ║"
echo "║                                                        ║"
echo "║  1. Set your passwords in archinstall.json            ║"
echo "║     (never commit the file with passwords set)        ║"
echo "║                                                        ║"
echo "║  2. curl -O https://raw.githubusercontent.com/        ║"
echo "║       manokel01/dotfiles-archniri/main/archinstall.json          ║"
echo "║     archinstall --config archinstall.json             ║"
echo "║                                                        ║"
echo "║  3. When archinstall finishes: do NOT reboot yet.     ║"
echo "║     Re-enable SSH, then run arch-setup.sh             ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"
