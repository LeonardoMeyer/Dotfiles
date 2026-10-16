#!/bin/bash
set -euo pipefail

# Applies a wallpaper and regenerates the theme (pywal, or the scheme chosen in the settings panel).
selected_wallpaper="${1:?usage: wallpaper-apply.sh <image>}"

awww img "$selected_wallpaper" --transition-type any --transition-fps 60 --transition-duration .5
"$(dirname "$(readlink -f "$0")")/color-apply.sh" "" "$selected_wallpaper"

mkdir -p ~/.cache/wallpaper-picker && printf "%s\n" "$selected_wallpaper" > ~/.cache/wallpaper-picker/current
cp -r "$selected_wallpaper" "$HOME/wallpapers/pywallpaper.jpg"
"$(dirname "$(readlink -f "$0")")/home-screen/home-wall.sh" >/dev/null 2>&1 &
