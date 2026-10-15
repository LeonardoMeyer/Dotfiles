#!/usr/bin/env bash
# Fixes the actionable warnings found in the boot journal (journalctl -b -p warning).
set -euo pipefail

[[ $EUID -ne 0 ]] || { echo "Run as your normal user; sudo is used where needed."; exit 1; }

# regulatory.db missing, coolercontrold liquidctl error, "FAT-fs not properly unmounted" (needs fsck.fat).
sudo pacman -S --needed --noconfirm wireless-regdb liquidctl dosfstools

# bootctl: "/boot ... world accessible, which is a security hole" (esp mounted with 0022 masks).
if grep -Eq '^\S+\s+/boot\s+vfat\s+\S*fmask=0022' /etc/fstab; then
    sudo sed -i -E '/^\S+\s+\/boot\s+vfat/ s/fmask=0022/fmask=0077/; /^\S+\s+\/boot\s+vfat/ s/dmask=0022/dmask=0077/' /etc/fstab
    sudo systemctl daemon-reload
    sudo mount -o remount /boot
fi
sudo chmod 600 /boot/loader/random-seed 2>/dev/null || true

echo "[✓] Done. Reboot, then check: journalctl -b -p warning --no-pager"
