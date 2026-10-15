#!/usr/bin/env bash
# Mirrors local configs into this dotfiles repo, only for items that already exist here.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mirror() {
    local src="$1" dest="$2"
    if [ ! -e "$src" ] && [ ! -L "$src" ]; then
        echo "skipped (missing locally): $src"
        return
    fi

    local src_real dest_real
    src_real="$(realpath -m -- "$src")"
    dest_real="$(realpath -m -- "$dest")"
    if [[ "$src_real" == "/" || "$dest_real" == "/" ||
        "$src_real" == "$dest_real" ||
        "$src_real" == "$dest_real/"* ||
        "$dest_real" == "$src_real/"* ]]; then
        echo "error: refusing to sync overlapping paths: $src -> $dest" >&2
        return 1
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
