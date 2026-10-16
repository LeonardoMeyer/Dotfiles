#!/bin/bash
set -uo pipefail

# Regenerates the desktop palette. Theme "pywal" (the default) derives it from the wallpaper;
# anything else is a scheme from ~/.config/wal/colorschemes/<dark|light>/<name>.json.
# usage: color-apply.sh [theme] [wallpaper]   (theme "" keeps the saved one)
HYPR="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
STATE="$HYPR/.color-theme"
SCHEMES="$HOME/.config/wal/colorschemes"

theme="${1:-}"
if [ -n "$theme" ]; then
    printf '%s\n' "$theme" > "$STATE"
else
    theme="$(cat "$STATE" 2>/dev/null || true)"
    theme="${theme:-pywal}"
fi

wallpaper="${2:-}"
[ -n "$wallpaper" ] || wallpaper="$(cat "$HOME/.cache/wallpaper-picker/current" 2>/dev/null || cat "$HOME/.cache/wal/wal" 2>/dev/null || true)"

if [ "$theme" != pywal ] && [ -f "$SCHEMES/$theme.json" ]; then
    flags=(-n)
    [ "${theme%%/*}" = light ] && flags+=(-l)
    wal --theme "$SCHEMES/$theme.json" "${flags[@]}" >/dev/null || exit 1
elif [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
    wal -i "$wallpaper" -n --cols16 >/dev/null || exit 1
else
    echo "No wallpaper to derive colors from." >&2
    exit 1
fi

cat ~/.cache/wal/colors-kitty.conf > ~/.config/kitty/current-theme.conf
pywalfox update >/dev/null 2>&1 || true

color1=$(awk 'match($0, /color2=\47(.*)\47/,a) { print a[1] }' ~/.cache/wal/colors.sh)
color2=$(awk 'match($0, /color3=\47(.*)\47/,a) { print a[1] }' ~/.cache/wal/colors.sh)
cava_config="$HOME/.config/cava/config"
sed -i "s/^gradient_color_1 = .*/gradient_color_1 = '$color1'/" "$cava_config"
sed -i "s/^gradient_color_2 = .*/gradient_color_2 = '$color2'/" "$cava_config"
pkill -USR2 cava 2>/dev/null || true

# style.lua reads the palette at load time, so borders need a config reload to follow.
hyprctl reload config-only >/dev/null 2>&1 || true
