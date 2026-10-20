a#!/usr/bin/env bash
set -euo pipefail

cd "$HOME/Dotfiles"

files=(
    .config/cava/config
    .config/kitty/current-theme.conf
    wallpapers/pywallpaper.jpg
    .config/wofi/style-wallpaper.css
    .config/wofi/style.css
    .config/wofi/style-waybar.css
)

# Temporarily reveal local changes
git update-index --no-skip-worktree -- "${files[@]}"

echo "Changes to the 6 local config files:"
git status --short -- "${files[@]}"


read -rp "Stage these files for GitHub? (y/N): " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    git add -- "${files[@]}"
    echo "Changes staged. Review with: git diff --cached"
else
    echo "Nothing staged."
fi

# Hide local changes again
git update-index --skip-worktree -- "${files[@]}"

echo "Done. Review staged changes before committing and pushing."
