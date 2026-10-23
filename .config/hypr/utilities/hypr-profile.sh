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

# utilities/<name> -> ../<style>/utilities/<name> for the active style. Rebuilt on every quickshell launch too
# (shells.sh), so a utility added by a pull is picked up without re-applying the profile.
links() {
    local style d
    style="$(cut -d/ -f1 "$HYPR/.active-profile" 2>/dev/null || true)"
    [ -n "$style" ] && [ -d "$HYPR/$style/utilities" ] || return 0
    # Only stale links go (another style's, or a utility that was removed); good ones are left alone.
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

    # settings.lua and overrides.lua belong to the settings panel, not to a profile (settings.lua is rewritten below).
    find "$HYPR" -maxdepth 1 -type f -name '*.lua' ! -name overrides.lua ! -name settings.lua -delete
    cp -a "$HYPR/$style/base"/*.lua "$HYPR/"
    cp -a "$src"/*.lua "$HYPR/"

    printf '%s/%s\n' "$style" "$variant" > "$HYPR/.active-profile"
    links

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
    links) links ;;
    *) echo "usage: hypr-profile.sh apply <style> <variant> [--offline] | list | links" >&2; exit 2 ;;
esac
