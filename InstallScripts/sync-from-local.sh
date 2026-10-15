#!/usr/bin/env bash
# Copies local configs into this dotfiles repo, only for items that already exist here.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sync() {
    local src="$1" dest="$2"
    if [ ! -e "$src" ]; then
        echo "skip (missing locally): $src"
        return
    fi
    if [ -d "$src" ]; then
        mkdir -p "$dest"
        cp -a "$src/." "$dest/"
    else
        cp -a "$src" "$dest"
    fi
    echo "synced: $src -> $dest"
}

# Everything in .config that exists in the repo
for item in "$DOTFILES_DIR"/.config/*; do
    [ -e "$item" ] || continue
    sync "$HOME/.config/$(basename "$item")" "$item"
done

sync "$HOME/wallpapers" "$DOTFILES_DIR/wallpapers"
sync "$HOME/.icons" "$DOTFILES_DIR/.icons"
sync "$HOME/.bashrc" "$DOTFILES_DIR/.bashrc"
