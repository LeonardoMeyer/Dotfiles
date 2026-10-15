# Arch boot splash (Pywal, ASCII card)

A dark Pywal background with one frosted card: ASCII Arch logo, a `#`/`-` character progress bar with percentage, and the 16 Pywal colors. All colors come from Pywal's last saved palette.

Plymouth starts in the initramfs, before your home directory or the Pywal cache exists, so the palette must be baked into the initramfs (`mkinitcpio -P`, needs root). Changing the wallpaper runs `apply.sh` in the background and sends a notification when done. The first `sudo ./install.sh` also installs a root-owned copy in `/usr/local/lib/boot-theme` and a sudoers rule (`/etc/sudoers.d/boot-theme`) so later runs need no password. Re-run it after editing the install scripts.

## Requirements

- `/etc/mkinitcpio.conf` HOOKS: `systemd` followed by `plymouth`; kernel parameter `splash`. The installer checks the hook order and does not edit bootloader entries.
- `python`, `python-pillow`, `python-numpy` (used at install time only to render the card).

## Install

```bash
sudo ./install.sh
```

The palette is also saved at `/usr/share/plymouth/themes/retro-modern-arch/pywal-palette.conf`. If the initramfs build fails, the installer restores the previous Plymouth theme and tries to rebuild with it. Do not reboot after a failed build.

## Roll back

```bash
sudo plymouth-set-default-theme --reset
sudo mkinitcpio -P
```

## Files

- `retro-modern-arch.script` – Plymouth script (layout, log lines, progress bar)
- `generate-assets.py` – renders the card image; its layout numbers must match the script
