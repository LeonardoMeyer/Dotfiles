#!/bin/bash

set -euo pipefail

WAYBAR_DIR="$HOME/.config/waybar"
ASSETS="$WAYBAR_DIR/assets"
THEMES="$WAYBAR_DIR/themes"

# Asset file name -> theme folder name.
declare -A THEME_FOR=([main]=default [experimental]=experimental [line]=line [zen]=zen)

menu() {
    local name
    for name in main experimental line zen; do
        [ -f "$ASSETS/$name.png" ] && printf 'img:%s:text:%s\n' "$ASSETS/$name.png" "${THEME_FOR[$name]^}"
    done
}

main() {
    local choice name theme
    choice="$(menu | wofi -c ~/.config/wofi/waybar -s ~/.config/wofi/style-waybar.css \
        --show dmenu --prompt "Select Waybar" -n || true)"
    [ -n "$choice" ] || exit 0

    name="${choice#img:$ASSETS/}"
    name="${name%%.png*}"
    theme="${THEME_FOR[$name]:-}"
    [ -n "$theme" ] || exit 0

    cat "$THEMES/$theme/style-$theme.css" > "$WAYBAR_DIR/style.css"
    cat "$THEMES/$theme/config-$theme" > "$WAYBAR_DIR/config"

    pkill -x waybar || true
    waybar >/dev/null 2>&1 &
}

main
