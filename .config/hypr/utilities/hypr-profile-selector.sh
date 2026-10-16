#!/bin/bash

set -euo pipefail

# ~/.config/hypr is a symlink into the dotfiles repo; find does not descend into a symlinked start path.
ACTIVE_HYPR_DIR="$(readlink -f "$HOME/.config/hypr")"
WOFI_CONFIG="$HOME/.config/wofi/profiles"
WOFI_STYLE="$HOME/.config/wofi/style-profiles.css"

# A profile is any folder here containing hyprland.lua (old/, utilities/, scripts/ excluded).
mapfile -t profiles < <(
    find "$ACTIVE_HYPR_DIR" -mindepth 1 -maxdepth 1 -type d \
        ! -name old ! -name utilities ! -name scripts \
        -exec test -f '{}/hyprland.lua' \; \
        -printf '%f\n' | sort
)

if [ "${#profiles[@]}" -eq 0 ]; then
    notify-send "Hyprland Profiles" "No profiles with hyprland.lua were found." 2>/dev/null || true
    exit 1
fi

main() {
    local active_profile=""
    [ -f "$ACTIVE_HYPR_DIR/.active-profile" ] && active_profile="$(<"$ACTIVE_HYPR_DIR/.active-profile")"

    local menu_entries=() profile
    for profile in "${profiles[@]}"; do
        if [ "$profile" = "$active_profile" ]; then
            menu_entries+=("$profile  (active)")
        else
            menu_entries+=("$profile")
        fi
    done

    local choice
    choice="$(printf '%s\n' "${menu_entries[@]}" | wofi \
        -c "$WOFI_CONFIG" \
        -s "$WOFI_STYLE" \
        --show dmenu \
        --prompt "Select Hyprland Profile" \
        -n || true)"

    [ -n "$choice" ] || exit 0

    local selected_profile=""
    for profile in "${profiles[@]}"; do
        [[ "$choice" == "$profile" || "$choice" == "$profile  (active)" ]] && selected_profile="$profile" && break
    done

    [ -n "$selected_profile" ] || exit 1

    local profile_dir="$ACTIVE_HYPR_DIR/$selected_profile"
    find "$ACTIVE_HYPR_DIR" -maxdepth 1 -type f -name '*.lua' -delete

    # utilities/ and hyprlock.conf are shared; only a profile's own files are swapped in.
    find "$profile_dir" -mindepth 1 -maxdepth 1 ! -name utilities ! -name hyprlock.conf -exec cp -a {} "$ACTIVE_HYPR_DIR/" \;

    # Profile-only utilities are added without ever overwriting shared ones.
    if [ -d "$profile_dir/utilities" ]; then
        cp -an "$profile_dir/utilities/." "$ACTIVE_HYPR_DIR/utilities/"
    fi

    printf '%s\n' "$selected_profile" > "$ACTIVE_HYPR_DIR/.active-profile"

    pkill -x waybar 2>/dev/null || true
    hyprctl reload
    if grep -qi 'waybar' "$ACTIVE_HYPR_DIR/startup.lua" 2>/dev/null; then
        waybar >/dev/null 2>&1 &
    fi
    notify-send "Hyprland Profile" "Loaded $selected_profile" 2>/dev/null || true
}

# The script file is replaced while running, so never read past this line.
main
exit
