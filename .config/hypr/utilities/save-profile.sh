#!/bin/bash
# Save the live root config back into the active profile.
# Reads .active-profile (e.g. "Modern/laptop"). machine.lua, and any file the variant already overrides,
# go back to the variant folder; every other .lua file and hyprlock.conf go to the style's shared base/.

set -euo pipefail

HYPR_DIR="${HYPR_DIR:-$HOME/.config/hypr}"
EXCLUDE=("overrides.lua" "settings.lua")   # owned by the settings panel, not by a profile

[[ -f "$HYPR_DIR/.active-profile" ]] || { echo "No .active-profile in $HYPR_DIR" >&2; exit 1; }

profile="$(tr -d '[:space:]' < "$HYPR_DIR/.active-profile")"
[[ -n "$profile" ]] || { echo ".active-profile is empty" >&2; exit 1; }

variant_dir="$HYPR_DIR/$profile"
base_dir="$HYPR_DIR/${profile%%/*}/base"
[[ -d "$variant_dir" && -d "$base_dir" ]] || { echo "Profile not found: $profile" >&2; exit 1; }

echo "Active profile: $profile"

shopt -s nullglob
for file in "$HYPR_DIR"/*.lua "$HYPR_DIR"/hyprlock.conf; do
    name="${file##*/}"
    skip=false
    for ex in "${EXCLUDE[@]}"; do
        [[ "$name" == "$ex" ]] && skip=true
    done
    $skip && { echo "skip  $name"; continue; }
    if [[ "$name" == machine.lua || -f "$variant_dir/$name" ]]; then
        dest="$variant_dir"
    else
        dest="$base_dir"
    fi
    cp -f "$file" "$dest/$name"
    echo "copy  $name -> ${dest#"$HYPR_DIR"/}"
done

echo "Done."
