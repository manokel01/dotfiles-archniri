#!/bin/bash
# pacman_updates.sh — Waybar custom/updates exec script
# Checks for official repo updates (checkupdates from pacman-contrib)
# and AUR updates (paru -Qu). Outputs JSON for Waybar return-type: json.
#
# Reboot detection: if /run/reboot-required exists OR if the running kernel
# differs from the installed kernel, signal a reboot-needed state.

# --- Count official repo updates ---
official=$(checkupdates 2>/dev/null)
official_count=$(echo "$official" | grep -c '^' 2>/dev/null)
# checkupdates outputs nothing if no updates — grep -c '^' on empty string gives 1
if [[ -z "$official" ]]; then
    official_count=0
fi

# --- Count AUR updates ---
aur=$(paru -Qua 2>/dev/null)
aur_count=$(echo "$aur" | grep -c '^' 2>/dev/null)
if [[ -z "$aur" ]]; then
    aur_count=0
fi

total=$((official_count + aur_count))

# --- Build tooltip ---
tooltip=""
if [[ $official_count -gt 0 ]]; then
    tooltip="Official: ${official_count}"
fi
if [[ $aur_count -gt 0 ]]; then
    [[ -n "$tooltip" ]] && tooltip+="\n"
    tooltip+="AUR: ${aur_count}"
fi
if [[ $total -eq 0 ]]; then
    tooltip="System is up to date"
fi

# --- Reboot detection ---
# Method 1: explicit flag (set by pacman hook or manual touch)
reboot_needed=false
if [[ -f /run/reboot-required ]]; then
    reboot_needed=true
fi
# Method 2: running kernel vs installed kernel
running_kernel=$(uname -r)
installed_kernel=$(pacman -Q linux 2>/dev/null | awk '{print $2}')
# Arch kernel version format: 6.13.4.arch1-1 → uname shows 6.13.4-arch1-1
# Normalize installed version for comparison
installed_kernel_normalized="${installed_kernel//.arch/-arch}"
if [[ -n "$installed_kernel" && "$running_kernel" != "$installed_kernel_normalized" ]]; then
    reboot_needed=true
fi

if [[ "$reboot_needed" == true ]]; then
    tooltip+="\n⚠ Reboot recommended"
fi

# --- Output JSON for Waybar ---
if [[ "$reboot_needed" == true ]]; then
    # Reboot state — class "reboot" triggers red background + blink in style.css
    echo "{\"text\": \" reboot\", \"tooltip\": \"${tooltip}\", \"class\": \"reboot\"}"
elif [[ $total -eq 0 ]]; then
    echo "{\"text\": \"󰏗\", \"tooltip\": \"${tooltip}\", \"class\": \"updated\"}"
else
    echo "{\"text\": \"󰏗 ${total}\", \"tooltip\": \"${tooltip}\", \"class\": \"\"}"
fi
