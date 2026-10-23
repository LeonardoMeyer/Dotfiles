#!/bin/bash
set -euo pipefail

HYPR="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
UTIL="$HYPR/utilities"

list() {
    local style variant
    for style in "$HYPR"/*/; do
        style="${style%/}"
        [ -d "$style/utilities" ] || continue
        for variant in "$style"/*/; do
            variant="${variant%/}"
            [ -f "$variant/machine.lua" ] && printf '%s/%s\n' "${style##*/}" "${variant##*/}"
        done
    done
}

apply() {
    local style="${1:?style}" variant="${2:?variant}" offline="${3:-}"
    local src="$HYPR/$style/$variant" d

    [ -f "$src/machine.lua" ] && [ -f "$HYPR/$style/base/hyprland.lua" ] && [ -d "$HYPR/$style/utilities" ] || {
        echo "Profile not found: $style/$variant" >&2
        exit 1
    }

    if [ "$offline" != "--offline" ]; then
        "$UTIL/shells.sh" stop
    fi

    # settings.lua and overrides.lua belong to the settings panel, not to a profile (settings.lua is rewritten below).
    find "$HYPR" -maxdepth 1 -type f -name '*.lua' ! -name overrides.lua ! -name settings.lua -delete
    cp -a "$HYPR/$style/base"/*.lua "$HYPR/"
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
    if grep -q 'bar.sh' "$HYPR/startup.lua" 2>/dev/null; then
        "$UTIL/bar.sh" start
    fi
    # The variant's live entry may carry its own color theme, bar and waybar style.
    python3 "$UTIL/hypr-settings.py" appearance
    notify-send "Hyprland Profile" "Loaded $style / $variant" 2>/dev/null || true
}

case "${1:-}" in
    apply) shift; apply "$@" ;;
    list) list ;;
    *) echo "usage: hypr-profile.sh apply <style> <variant> [--offline] | list" >&2; exit 2 ;;
esac
