#!/bin/bash

set -euo pipefail

# Wofi picker for the active style's waybar styles (the settings panel offers the same list).
HYPR="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
style="$(cut -d/ -f1 "$HYPR/.active-profile")"

menu() {
    local d name
    for d in "$HYPR/$style/waybar"/*/; do
        name="$(basename "$d")"
        [ -f "$d/preview.png" ] && printf 'img:%s:text:%s\n' "$d/preview.png" "${name^}"
    done
}

choice="$(menu | wofi -c ~/.config/wofi/waybar -s ~/.config/wofi/style-waybar.css \
    --show dmenu --prompt "Select Waybar" -n || true)"
[ -n "$choice" ] || exit 0

name="${choice#img:$HYPR/$style/waybar/}"
exec "$HYPR/utilities/waybar-style.sh" apply "${name%%/*}"
