#!/usr/bin/env bash
set -euo pipefail
THEME=retro-modern-arch
SRC="$(cd -- "$(dirname -- "$0")" && pwd)"
DEST="/usr/share/plymouth/themes/$THEME"
if [[ $EUID -ne 0 ]]; then echo "Run: sudo ./install.sh"; exit 1; fi
[[ -f "$SRC/$THEME.plymouth" && -f "$SRC/$THEME.script" ]] || { echo "Theme files missing; extract the full ZIP first."; exit 1; }

if [[ -n ${SUDO_USER:-} && $SUDO_USER != root ]]; then
  PYWAL_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
elif [[ -n ${PKEXEC_UID:-} && $PKEXEC_UID != 0 ]]; then
  PYWAL_HOME="$(getent passwd "$PKEXEC_UID" | cut -d: -f6)"
else
  PYWAL_HOME="${HOME:-}"
fi
PYWAL_COLORS="$PYWAL_HOME/.cache/wal/colors"
if [[ -z $PYWAL_HOME || ! -r $PYWAL_COLORS ]]; then
  echo "Could not read the last Pywal palette at $PYWAL_COLORS." >&2
  echo "Generate a Pywal theme first, then run this installer with sudo." >&2
  exit 1
fi
palette=()
while IFS= read -r color || [[ -n $color ]]; do
  color="${color//[[:space:]]/}"
  [[ -z $color ]] && continue
  if [[ ! $color =~ ^#[[:xdigit:]]{6}$ ]]; then
    echo "Invalid Pywal color in $PYWAL_COLORS: $color" >&2
    exit 1
  fi
  palette+=("${color,,}")
done < "$PYWAL_COLORS"
if [[ ${#palette[@]} -ne 16 ]]; then
  echo "Expected 16 colors in $PYWAL_COLORS, found ${#palette[@]}." >&2
  exit 1
fi

CONF=/etc/mkinitcpio.conf
if [[ ! -r "$CONF" ]]; then
  echo "Cannot read $CONF; configure the systemd and plymouth hooks before installing." >&2
  exit 1
fi
if ! (
  set +u
  source "$CONF"
  systemd_index=-1
  plymouth_index=-1
  for i in "${!HOOKS[@]}"; do
    [[ ${HOOKS[$i]} == systemd ]] && systemd_index=$i
    [[ ${HOOKS[$i]} == plymouth ]] && plymouth_index=$i
  done
  [[ $systemd_index -ge 0 && $plymouth_index -gt $systemd_index ]]
); then
  echo "The HOOKS array in $CONF must contain 'systemd' followed by 'plymouth'." >&2
  echo "Add the hooks in the correct order, then run this installer again." >&2
  exit 1
fi
if ! python3 -c 'import PIL, numpy' 2>/dev/null; then
  echo "python3 with Pillow and NumPy is required to render the splash images (pacman -S python-pillow python-numpy)." >&2
  exit 1
fi
OLD_THEME="$(plymouth-set-default-theme 2>/dev/null || true)"
mkdir -p "$DEST"
install -m 644 "$SRC/$THEME.plymouth" "$DEST/$THEME.plymouth"
script_tmp="$(mktemp "$DEST/.$THEME.script.XXXXXX")"
palette_tmp="$(mktemp "$DEST/.pywal-palette.conf.XXXXXX")"
assets_tmp="$(mktemp -d "$DEST/.assets.XXXXXX")"
trap 'rm -rf "$script_tmp" "$palette_tmp" "$assets_tmp"' EXIT
for i in "${!palette[@]}"; do
  hex="${palette[$i]#\#}"
  red_hex="${hex:0:2}"; green_hex="${hex:2:2}"; blue_hex="${hex:4:2}"
  red=$((16#$red_hex)); green=$((16#$green_hex)); blue=$((16#$blue_hex))
  red_scaled=$((red * 1000000 / 255))
  green_scaled=$((green * 1000000 / 255))
  blue_scaled=$((blue * 1000000 / 255))
  printf -v red_value '%d.%06d' "$((red_scaled / 1000000))" "$((red_scaled % 1000000))"
  printf -v green_value '%d.%06d' "$((green_scaled / 1000000))" "$((green_scaled % 1000000))"
  printf -v blue_value '%d.%06d' "$((blue_scaled / 1000000))" "$((blue_scaled % 1000000))"
  printf 'wal%sR=%s; wal%sG=%s; wal%sB=%s;\n' \
    "$i" "$red_value" "$i" "$green_value" "$i" "$blue_value" >> "$script_tmp"
  printf 'color%s=%s\n' "$i" "${palette[$i]}" >> "$palette_tmp"
done
cat "$SRC/$THEME.script" >> "$script_tmp"
python3 "$SRC/generate-assets.py" "$palette_tmp" "$assets_tmp" "$SRC/preview.png"
chmod 755 "$assets_tmp"; chmod 644 "$assets_tmp"/*
rm -rf "$DEST/assets"
mv "$assets_tmp" "$DEST/assets"
install -m 644 "$script_tmp" "$DEST/$THEME.script"
install -m 644 "$palette_tmp" "$DEST/pywal-palette.conf"
rm -f "$script_tmp" "$palette_tmp"

# Live log lines for the splash card
install -m 755 "$SRC/plymouth-logfeed.sh" /usr/local/bin/plymouth-logfeed
install -m 644 "$SRC/plymouth-logfeed.service" /etc/systemd/system/plymouth-logfeed.service
systemctl daemon-reload
systemctl enable plymouth-logfeed.service
if ! plymouth-set-default-theme "$THEME"; then echo "Could not set theme."; exit 1; fi
if ! mkinitcpio -P; then
  echo "ERROR: mkinitcpio failed; restoring the previous Plymouth theme." >&2
  if [[ -n "$OLD_THEME" ]]; then
    plymouth-set-default-theme "$OLD_THEME" || { echo "ERROR: could not restore the previous theme." >&2; exit 1; }
  else
    plymouth-set-default-theme --reset || { echo "ERROR: could not reset the Plymouth theme." >&2; exit 1; }
  fi
  if ! mkinitcpio -P; then
    echo "ERROR: initramfs rebuild also failed while restoring the previous theme." >&2
  fi
  exit 1
fi

# Remove leftovers from an accidentally extracted initramfs; the theme files are kept.
if [[ -e "$SRC/init_functions" && -e "$SRC/buildconfig" ]]; then
  for stray in bin buildconfig config dev early_cpio etc init init_functions kernel lib lib64 new_root proc run sbin sys sysroot tmp usr var VERSION; do
    rm -rf --one-file-system -- "${SRC:?}/$stray"
  done
  echo "Removed extracted initramfs files from $SRC."
fi
echo "Installed the Arch boot card using the last saved Pywal palette. All mkinitcpio presets were rebuilt."
echo "Ensure your boot entry includes the 'splash' kernel parameter, then reboot to test."
