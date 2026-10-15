#!/bin/bash
# Optionally back up the current config, then apply the dotfiles.
# Live pywal-generated files are preserved across the apply.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fullinstall.sh"

[[ -d "$DOTFILES_DIR" ]] || { error "Dotfiles directory not found: $DOTFILES_DIR"; exit 1; }

select_hyprland_style

read -rp "Back up current dotfiles? (Y/n): " choice
if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
    backup_config
    backup_bashrc
fi

# Save the live pywal state; the repo only holds stale snapshots of these.
keep=(wallpapers/pywallpaper.jpg .config/kitty/current-theme.conf)
live="$(mktemp -d)"
trap 'rm -rf "$live"' EXIT

for f in "${keep[@]}"; do
    [[ -f "$HOME/$f" ]] && install -D -m 644 "$HOME/$f" "$live/$f"
done
gradient=""
if [[ -f "$HOME/.config/cava/config" ]]; then
    gradient="$(grep -E '^gradient_color_[0-9]+ = ' "$HOME/.config/cava/config" || true)"
fi

apply_dotfiles

for f in "${keep[@]}"; do
    [[ -f "$live/$f" ]] && cp -a "$live/$f" "$HOME/$f"
done
while IFS=' ' read -r key _ value; do
    [[ -n "$key" ]] && sed -i "s|^$key = .*|$key = $value|" "$HOME/.config/cava/config"
done <<< "$gradient"

