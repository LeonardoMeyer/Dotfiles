#!/usr/bin/env bash
# Mirrors local configs into this dotfiles repo, only for items that already exist here.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mirror() {
    local src="$1" dest="$2"
    if [ ! -e "$src" ] && [ ! -L "$src" ]; then
        rm -rf "$dest"
        echo "removed (missing locally): $dest"
        return
    fi
    rm -rf "$dest"
    cp -a "$src" "$dest"
    echo "mirrored: $src -> $dest"
}

# Everything in .config that exists in the repo
shopt -s nullglob dotglob
for item in "$DOTFILES_DIR"/.config/*; do
    mirror "$HOME/.config/$(basename "$item")" "$item"
done

mirror "$HOME/wallpapers" "$DOTFILES_DIR/wallpapers"
mirror "$HOME/.icons" "$DOTFILES_DIR/.icons"
mirror "$HOME/.bashrc" "$DOTFILES_DIR/.bashrc"
