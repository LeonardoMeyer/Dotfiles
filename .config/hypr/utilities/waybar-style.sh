#!/bin/bash
set -euo pipefail

# Waybar styles belong to a Hyprland style: hypr/<style>/waybar/<name>/{config,style.css,preview.png}.
# Adding one is just a new folder.
#   waybar-style.sh apply <name>    install it as the live waybar config and restart waybar
#   waybar-style.sh list            names available for the active style
HYPR="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
WAYBAR="$HOME/.config/waybar"

style="$(cut -d/ -f1 "$HYPR/.active-profile" 2>/dev/null || true)"
dir="$HYPR/$style/waybar"

case "${1:-}" in
    list)
        for d in "$dir"/*/; do
            [ -f "$d/config" ] && basename "$d"
        done
        ;;
    apply)
        name="${2:?name}"
        [ -f "$dir/$name/config" ] && [ -f "$dir/$name/style.css" ] || {
            echo "No waybar style '$name' for $style" >&2
            exit 1
        }
        cp "$dir/$name/config" "$WAYBAR/config"
        cp "$dir/$name/style.css" "$WAYBAR/style.css"
        # waybar reloads its style on change; a restart picks up the new module layout.
        pkill -x waybar 2>/dev/null || true
        setsid -f waybar >/dev/null 2>&1 </dev/null
        # Remembered by the live profile entry, like its wallpaper (not when the panel re-applies an entry,
        # or when the panel records the pick itself).
        [ -n "${HYPR_SETTINGS_NO_RECORD:-}" ] || python3 "$HYPR/utilities/hypr-settings.py" set "waybar.style=\"$name\"" >/dev/null 2>&1 || true
        ;;
    *)
        echo "usage: waybar-style.sh apply <name> | list" >&2
        exit 2
        ;;
esac
