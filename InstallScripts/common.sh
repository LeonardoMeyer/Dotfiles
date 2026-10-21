#!/bin/bash

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[•]${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[!]${RESET} $*"; }
error()   { echo -e "${RED}${BOLD}[✗]${RESET} $*" >&2; }
section() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

DOTFILES_DIR="${HOME}/Dotfiles"
CONFIG_DIR="${HOME}/.config"

ensure_prereqs() {
    if [ ! -d "$DOTFILES_DIR" ]; then
        error "Dotfiles directory not found at $DOTFILES_DIR"
        exit 1
    fi

    if ! command -v yay >/dev/null 2>&1; then
        error "'yay' not found. Install yay first and rerun."
        exit 1
    fi

    mkdir -p "$CONFIG_DIR"
}

install_packages() {
    local packages=("$@")
    if [ "${#packages[@]}" -eq 0 ]; then
        return
    fi
    info "Installing packages: ${packages[*]}"
    yay -S --needed "${packages[@]}"
}

copy_config_dir() {
    local src_rel="$1"
    local dest_rel="$2"
    local src="$DOTFILES_DIR/.config/$src_rel"
    local dest="$CONFIG_DIR/$dest_rel"

    if [ ! -d "$src" ]; then
        warn "Missing source directory: $src"
        return
    fi

    mkdir -p "$dest"
    cp -a "$src/." "$dest/"
    success "Copied $src_rel -> ~/.config/$dest_rel"
}

copy_config_file() {
    local src_rel="$1"
    local dest_rel="$2"
    local src="$DOTFILES_DIR/.config/$src_rel"
    local dest="$CONFIG_DIR/$dest_rel"

    if [ ! -f "$src" ]; then
        warn "Missing source file: $src"
        return
    fi

    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
    success "Copied $src_rel -> ~/.config/$dest_rel"
}

apply_default_pywal() {
    local wallpaper="$DOTFILES_DIR/wallpapers/pywallpaper.jpg"

    if ! command -v wal >/dev/null 2>&1; then
        warn "'wal' command not found, skipping initial pywal theme setup."
        return
    fi

    if [ ! -f "$wallpaper" ]; then
        warn "Wallpaper not found at $wallpaper, skipping pywal theme setup."
        return
    fi

    info "Applying default pywal theme."
    wal -i "$wallpaper" -n
}
