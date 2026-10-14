#!/bin/bash
set -euo pipefail

# Workspace overview: lists workspaces with their windows and jumps to the chosen one.
menu="$(hyprctl workspaces -j | jq -r '
    sort_by(.id) | .[] | select(.id > 0) |
    "\(.id)\t󰍹  Workspace \(.id)  (\(.windows) windows)  \(.lastwindowtitle)"')"

[ -n "$menu" ] || exit 0

choice="$(cut -f2 <<<"$menu" | wofi \
    -c "$HOME/.config/wofi/profiles" \
    -s "$HOME/.config/wofi/style-profiles.css" \
    --show dmenu --prompt "Workspaces" -n || true)"

[ -n "$choice" ] || exit 0

id="$(grep -F -- "$choice" <<<"$menu" | head -n1 | cut -f1)"
hyprctl dispatch workspace "$id"
