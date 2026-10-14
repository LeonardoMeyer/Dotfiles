# Arch boot splash (Pywal, ASCII card)

A dark Pywal background with one frosted card: ASCII Arch logo, the last one or two lines of the live system log, a `#`/`-` character progress bar with percentage, and the 16 Pywal colors. All colors come from Pywal's last saved palette.

Plymouth starts in the initramfs, before your home directory or the Pywal cache exists. The installer reads `~/.cache/wal/colors`, renders the card image from it, embeds the palette in the theme, and rebuilds all mkinitcpio presets. After a new Pywal palette, run the installer again (`apply.sh` does this) to update the next boot.

## Live log lines

`plymouth-logfeed.service` (installed to `/etc/systemd/system`, script at `/usr/local/bin/plymouth-logfeed`) follows the journal during boot and sends about six lines per second to the splash with `plymouth display-message`. It stops by itself once Plymouth quits. Lines from the first moments in the initramfs are not shown; the card says "starting system..." until the first journal line arrives.

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
sudo systemctl disable plymouth-logfeed.service
sudo plymouth-set-default-theme --reset
sudo mkinitcpio -P
```

## Files

- `retro-modern-arch.script` – Plymouth script (layout, log lines, progress bar)
- `generate-assets.py` – renders the card image; its layout numbers must match the script
- `plymouth-logfeed.sh` / `.service` – journal to splash feed
