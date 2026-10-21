#!/bin/bash
# Symlink everything in the dotfiles repo into $HOME. Edits on either side are
# the same files, so no syncing is needed; new top-level entries are picked up
# by re-running this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fullinstall.sh"

[[ -d "$DOTFILES_DIR" ]] || { error "Dotfiles directory not found: $DOTFILES_DIR"; exit 1; }

select_hyprland_style
apply_dotfiles
