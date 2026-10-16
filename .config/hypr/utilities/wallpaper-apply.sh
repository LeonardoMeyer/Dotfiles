#!/bin/bash
set -euo pipefail

# Applies a wallpaper and regenerates the pywal-driven theme.
selected_wallpaper="${1:?usage: wallpaper-apply.sh <image>}"

awww img "$selected_wallpaper" --transition-type any --transition-fps 60 --transition-duration .5
wal -i "$selected_wallpaper" -n --cols16
cat ~/.cache/wal/colors-kitty.conf > ~/.config/kitty/current-theme.conf
pywalfox update

color1=$(awk 'match($0, /color2=\47(.*)\47/,a) { print a[1] }' ~/.cache/wal/colors.sh)
color2=$(awk 'match($0, /color3=\47(.*)\47/,a) { print a[1] }' ~/.cache/wal/colors.sh)
cava_config="$HOME/.config/cava/config"
sed -i "s/^gradient_color_1 = .*/gradient_color_1 = '$color1'/" "$cava_config"
sed -i "s/^gradient_color_2 = .*/gradient_color_2 = '$color2'/" "$cava_config"
pkill -USR2 cava 2>/dev/null || true

mkdir -p ~/.cache/wallpaper-picker && printf "%s\n" "$selected_wallpaper" > ~/.cache/wallpaper-picker/current
cp -r "$selected_wallpaper" "$HOME/wallpapers/pywallpaper.jpg"
"$(dirname "$(readlink -f "$0")")/home-screen/home-wall.sh" >/dev/null 2>&1 &
