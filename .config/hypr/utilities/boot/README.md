# Arch boot splash (Pywal, ASCII card)

A dark Pywal background with one frosted card: ASCII Arch logo, the last one or two lines of the live system log, a `#`/`-` character progress bar with percentage, and the 16 Pywal colors. All colors come from Pywal's last saved palette.

Plymouth starts in the initramfs, before your home directory or the Pywal cache exists, so the palette must be baked into the initramfs (`mkinitcpio -P`, needs root). Changing the wallpaper runs `apply.sh` in the background and sends a notification when done. The first `sudo ./install.sh` also installs a root-owned copy in `/usr/local/lib/boot-theme` and a sudoers rule (`/etc/sudoers.d/boot-theme`) so later runs need no password. Re-run it after editing the install scripts.

## Live log lines

`plymouth-logfeed.service` (installed to `/etc/systemd/system`, script at `/usr/local/bin/plymouth-logfeed`) follows the journal during boot and sends about six lines per second to the splash with `plymouth display-message`. It stops by itself once Plymouth quits. Lines from the first moments in the initramfs are not shown; the card says "starting system..." until the first journal line arrives.

## Hand-off

`plymouth-handoff` (a drop-in on `plymouth-quit.service`) stops the live log feed, fills the bar to 100% with a `@100` message, then runs `plymouth quit --retain-splash`. Plymouth's stock `plymouth-quit-wait.service` releases greetd as soon as Plymouth exits; the last frame remains until greetd or Hyprland draws over it. No watcher or fixed startup wait is used.

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
sudo rm -f /etc/systemd/system/plymouth-quit.service.d/handoff.conf /usr/local/bin/plymouth-handoff /usr/local/bin/plymouth-handoff-watch /etc/systemd/system/greetd.service.d/plymouth-handoff.conf
sudo plymouth-set-default-theme --reset
sudo mkinitcpio -P
```

## Files

- `retro-modern-arch.script` – Plymouth script (layout, log lines, progress bar)
- `generate-assets.py` – renders the card image; its layout numbers must match the script
- `plymouth-handoff.sh` – finish the bar, then retain its final frame for greetd/Hyprland
- `plymouth-logfeed.sh` / `.service` – journal to splash feed
