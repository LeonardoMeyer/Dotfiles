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

# link utilities/<name> to the active style
links() {
    local style d
    style="$(cut -d/ -f1 "$HYPR/.active-profile" 2>/dev/null || true)"
    [ -n "$style" ] && [ -d "$HYPR/$style/utilities" ] || return 0
    for d in "$UTIL"/*; do
        if [ -L "$d" ] && { [ "$(readlink "$d")" != "../$style/utilities/${d##*/}" ] || [ ! -e "$d" ]; }; then
            rm -f "$d"
        fi
    done
    for d in "$HYPR/$style/utilities"/*/; do
        d="$(basename "$d")"
        if [ ! -L "$UTIL/$d" ]; then ln -s "../$style/utilities/$d" "$UTIL/$d"; fi
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

    # these belong to the settings panel
    find "$HYPR" -maxdepth 1 -type f -name '*.lua' ! -name overrides.lua ! -name settings.lua -delete
    cp -a "$HYPR/$style/base"/*.lua "$HYPR/"
    cp -a "$src"/*.lua "$HYPR/"

    printf '%s/%s\n' "$style" "$variant" > "$HYPR/.active-profile"
    links

    python3 "$UTIL/hypr-settings.py" sync

    [ "$offline" = "--offline" ] && return 0

    hyprctl reload >/dev/null 2>&1 || true
    python3 "$UTIL/hypr-settings.py" cursor
    "$UTIL/shells.sh" start
    if grep -q 'bar.sh' "$HYPR/startup.lua" 2>/dev/null; then
        "$UTIL/bar.sh" start
    fi
    python3 "$UTIL/hypr-settings.py" appearance
    notify-send "Hyprland Profile" "Loaded $style / $variant" 2>/dev/null || true
}

case "${1:-}" in
    apply) shift; apply "$@" ;;
    list) list ;;
    links) links ;;
    *) echo "usage: hypr-profile.sh apply <style> <variant> [--offline] | list | links" >&2; exit 2 ;;
esac
