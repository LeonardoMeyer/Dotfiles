#!/usr/bin/env bash
# Rebuilds the boot splash with the current Pywal palette (run in the background after a wallpaper change).
set -uo pipefail

DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LOG="${XDG_RUNTIME_DIR:-/tmp}/boot-theme-install.log"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/boot-theme-install.lock"
ROOT_INSTALL=/usr/local/lib/boot-theme/install.sh

notify() { notify-send -a "Boot screen" -i "${3:-dialog-information}" -u "${2:-normal}" "Boot screen" "$1" 2>/dev/null || true; }

# Boot theme not installed or Plymouth removed: nothing to update, stay silent.
[[ -x $ROOT_INSTALL && -d /usr/share/plymouth/themes/retro-modern-arch ]] || exit 0
command -v plymouth-set-default-theme >/dev/null 2>&1 && command -v mkinitcpio >/dev/null 2>&1 || exit 0

# Block shutdown for the whole run, including time queued behind another rebuild.
if [[ -z ${BOOT_APPLY_INHIBITED:-} ]] && command -v systemd-inhibit >/dev/null 2>&1; then
    exec env BOOT_APPLY_INHIBITED=1 systemd-inhibit --what=shutdown:sleep --who="boot-theme" \
        --why="Updating boot theme" --mode=block "$0" "$@"
fi

exec 9>"$LOCK"
flock -w 600 9 || exit 75

if sudo -n "$ROOT_INSTALL" >"$LOG" 2>&1; then
    notify "Boot theme updated. It applies on next boot." normal "$DIR/preview.png"
    exit 0
fi
notify "Boot theme update failed. Log: $LOG" critical dialog-error
exit 1
