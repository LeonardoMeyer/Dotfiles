#!/bin/bash
# Save the live root config back into the active profile.
# Reads .active-profile (relative path like "Modern/laptop") and copies
# root .lua files plus hyprlock.conf into that profile folder.

set -euo pipefail

HYPR_DIR="${HYPR_DIR:-$HOME/.config/hypr}"
EXCLUDE=("overrides.lua" "settings.lua")   # add "settings.lua" here to skip the panel-generated file too

[[ -f "$HYPR_DIR/.active-profile" ]] || { echo "No .active-profile in $HYPR_DIR" >&2; exit 1; }

profile="$(tr -d '[:space:]' < "$HYPR_DIR/.active-profile")"
dest="$HYPR_DIR/$profile"

[[ -n "$profile" ]] || { echo ".active-profile is empty" >&2; exit 1; }
[[ -d "$dest" ]] || { echo "Profile directory not found: $dest" >&2; exit 1; }

echo "Active profile: $profile"

shopt -s nullglob
for file in "$HYPR_DIR"/*.lua "$HYPR_DIR"/hyprlock.conf; do
    name="${file##*/}"
    skip=false
    for ex in "${EXCLUDE[@]}"; do
        [[ "$name" == "$ex" ]] && skip=true
    done
    $skip && { echo "skip  $name"; continue; }
    cp -f "$file" "$dest/$name"
    echo "copy  $name"
done

echo "Done."
