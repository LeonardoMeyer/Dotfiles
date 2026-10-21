#!/bin/bash
set -euo pipefail

# Activates a Hyprland profile: hypr/<style>/<variant>/*.lua become the active config and
# hypr/<style>/utilities/* become the active quickshells (symlinked into hypr/utilities/).
# Adding a style is just a new folder: <style>/{laptop,desktop,...}/ with hyprland.lua, plus <style>/utilities/.
#
# usage: hypr-profile.sh apply <style> <variant> [--offline]
#        hypr-profile.sh list
HYPR="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
UTIL="$HYPR/utilities"

list() {
    local style variant
    for style in "$HYPR"/*/; do
        style="${style%/}"
        [ -d "$style/utilities" ] || continue
        for variant in "$style"/*/; do
            variant="${variant%/}"
            [ -f "$variant/hyprland.lua" ] && printf '%s/%s\n' "${style##*/}" "${variant##*/}"
        done
    done
}

apply() {
    local style="${1:?style}" variant="${2:?variant}" offline="${3:-}"
    local src="$HYPR/$style/$variant" d

    [ -f "$src/hyprland.lua" ] && [ -d "$HYPR/$style/utilities" ] || {
        echo "Profile not found: $style/$variant" >&2
        exit 1
    }

    if [ "$offline" != "--offline" ]; then
        "$UTIL/shells.sh" stop
    fi

    # settings.lua and overrides.lua belong to the settings panel, not to a profile (settings.lua is rewritten below).
    find "$HYPR" -maxdepth 1 -type f -name '*.lua' ! -name overrides.lua ! -name settings.lua -delete
    cp -a "$src"/*.lua "$HYPR/"

    find "$UTIL" -maxdepth 1 -type l -delete
    for d in "$HYPR/$style/utilities"/*/; do
        ln -s "../$style/utilities/$(basename "$d")" "$UTIL/$(basename "$d")"
    done

    printf '%s/%s\n' "$style" "$variant" > "$HYPR/.active-profile"

    # Each style/variant keeps its own tweaks (hypr/tweaks/); swap in the new profile's.
    python3 "$UTIL/hypr-settings.py" sync

    [ "$offline" = "--offline" ] && return 0

    hyprctl reload >/dev/null 2>&1 || true
    python3 "$UTIL/hypr-settings.py" cursor
    "$UTIL/shells.sh" start
    if grep -qi 'waybar' "$HYPR/startup.lua" 2>/dev/null; then
        pkill -x waybar 2>/dev/null || true
        setsid -f waybar >/dev/null 2>&1
    fi
    # The variant's live entry may carry its own color theme and waybar style.
    python3 "$UTIL/hypr-settings.py" appearance
    notify-send "Hyprland Profile" "Loaded $style / $variant" 2>/dev/null || true
}

case "${1:-}" in
    apply) shift; apply "$@" ;;
    list) list ;;
    *) echo "usage: hypr-profile.sh apply <style> <variant> [--offline] | list" >&2; exit 2 ;;
esac
