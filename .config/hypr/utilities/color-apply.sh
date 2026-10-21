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

# Terminal cava mirrors the music player's visualizer: the same left-to-right pywal gradient
# (Theme.spectrum) and the same feed settings as music/cava.conf.
walc() { awk -v k="$1" 'match($0, "^" k "=\47(.*)\47", a) { print a[1] }' ~/.cache/wal/colors.sh; }
cat > "$HOME/.config/cava/config" <<CAVA
[general]
framerate = 60
autosens = 1
lower_cutoff_freq = 50
higher_cutoff_freq = 12000
bar_width = 2
bar_spacing = 1

[output]
channels = mono
mono_option = average

[color]
horizontal_gradient = 1
horizontal_gradient_count = 5
horizontal_gradient_color_1 = '$(walc color4)'
horizontal_gradient_color_2 = '$(walc color9)'
horizontal_gradient_color_3 = '$(walc color13)'
horizontal_gradient_color_4 = '$(walc color12)'
horizontal_gradient_color_5 = '$(walc color14)'

[smoothing]
noise_reduction = 72
CAVA
# USR1 reloads the whole config (USR2 only re-reads colors).
pkill -USR1 cava 2>/dev/null || true

# style.lua reads the palette at load time, so borders need a config reload to follow.
hyprctl reload config-only >/dev/null 2>&1 || true
