#!/bin/bash
# Waybar on its own: one of the styles in hypr/<style>/waybar/<name>/, copied into ~/.config/waybar with its
# scripts. Nothing else from these dotfiles is needed, and nothing points back into the repo, so it keeps working
# if the repo is moved or deleted. Runs without the full install and without any other installer script.

set -euo pipefail

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

info()    { echo -e "${CYAN}${BOLD}[•]${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[!]${RESET} $*"; }
error()   { echo -e "${RED}${BOLD}[✗]${RESET} $*" >&2; }
section() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

# The repo this script sits in, wherever it was cloned.
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
DEST="$HOME/.config/waybar"
STYLE_DIR=""

PACKAGES=(
    waybar otf-codenewroman-nerd hyprpicker wl-clipboard libnotify pacman-contrib
    kitty networkmanager bluez bluez-utils blueman
)
# AUR only: installed when an AUR helper is around, otherwise the bar falls back to a built-in palette.
AUR_PACKAGES=(python-pywal16)

# ── Packages ───────────────────────────────────────────────────────────────

install_packages() {
    local helper=""
    command -v yay >/dev/null && helper=yay
    [[ -z "$helper" ]] && command -v paru >/dev/null && helper=paru

    if [[ -n "$helper" ]]; then
        "$helper" -S --needed "${PACKAGES[@]}" "${AUR_PACKAGES[@]}"
    elif command -v pacman >/dev/null; then
        warn "No AUR helper (yay/paru) found; skipping ${AUR_PACKAGES[*]}."
        sudo pacman -S --needed "${PACKAGES[@]}"
    else
        warn "Not an Arch system; install these yourself: ${PACKAGES[*]} pywal16"
    fi
}

# ── Style ──────────────────────────────────────────────────────────────────

select_style() {
    section "Waybar Style"

    local styles=() d i=1 choice
    for d in "$REPO"/.config/hypr/*/waybar/*/; do
        [[ -f "$d/config" && -f "$d/style.css" ]] && styles+=("${d%/}")
    done
    [[ ${#styles[@]} -gt 0 ]] || { error "No waybar styles found under $REPO/.config/hypr/."; exit 1; }

    for d in "${styles[@]}"; do
        # <style>/waybar/<name> → "Modern — default"
        echo "$i. $(basename "$(dirname "$(dirname "$d")")") — $(basename "$d")"
        ((i += 1))
    done
    echo "   (previews: $REPO/.config/hypr/<style>/waybar/<name>/preview.png)"

    read -rp "Choose a style [1]: " choice
    choice="${choice:-1}"
    [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#styles[@]})) ||
        { error "Invalid style."; exit 1; }

    STYLE_DIR="${styles[$((choice - 1))]}"
    success "Selected $(basename "$STYLE_DIR")"
}

# ── Config ─────────────────────────────────────────────────────────────────

install_config() {
    section "Installing Waybar Config"

    # A full install links ~/.config/waybar into the repo; writing through that link would change the repo, so
    # the link is swapped for a real folder (the repo itself is left as it is).
    if [[ -L "$DEST" ]]; then
        warn "$DEST was a link to $(readlink -f "$DEST"); replacing it with a standalone copy."
        rm "$DEST"
    elif [[ -e "$DEST" && ! -e "$DEST/.standalone" ]]; then
        local backup="$DEST.backup_$(date +%Y%m%d_%H%M%S)"
        mv "$DEST" "$backup"
        warn "Moved the old config to $backup"
    fi

    mkdir -p "$DEST/scripts"
    cp "$STYLE_DIR/config" "$DEST/config"
    cp "$STYLE_DIR/style.css" "$DEST/style.css"
    cp -a "$REPO/.config/waybar/scripts/." "$DEST/scripts/"
    chmod +x "$DEST"/scripts/*.sh
    # Marks the folder as this installer's, so picking another style later replaces it without a backup.
    echo "$(basename "$STYLE_DIR")" > "$DEST/.standalone"

    # The notification button opens the dotfiles' home screen, which only exists with the full install.
    if [[ ! -x "$HOME/.config/hypr/utilities/shells.sh" ]]; then
        sed -i 's|"custom/notification",\s*||' "$DEST/config"
    fi

    success "Installed to $DEST"
}

# style.css imports ~/.cache/wal/colors-waybar.css; without it waybar refuses the stylesheet and draws unstyled.
ensure_palette() {
    local css="$HOME/.cache/wal/colors-waybar.css" wallpaper="$REPO/wallpapers/pywallpaper.jpg"

    [[ -f "$css" ]] && { success "Using your existing pywal palette."; return; }

    if command -v wal >/dev/null && [[ -f "$wallpaper" ]]; then
        info "Generating a pywal palette from the default wallpaper."
        # -n: leave the wallpaper alone; -s -t: don't recolor open terminals.
        wal -q -n -s -t -i "$wallpaper" || true
    fi
    [[ -f "$css" ]] && { success "Pywal palette generated."; return; }

    # Until pywal runs (wal -i <image>), a neutral dark palette with the same names.
    mkdir -p "$(dirname "$css")"
    cat > "$css" <<'EOF'
@define-color foreground #c7c6c2;
@define-color background #101418;
@define-color cursor #c7c6c2;
@define-color color0 #101418;
@define-color color1 #e06c75;
@define-color color2 #98c379;
@define-color color3 #e5c07b;
@define-color color4 #5f87af;
@define-color color5 #c3a6ff;
@define-color color6 #9fe0d0;
@define-color color7 #c7c6c2;
@define-color color8 #5c6370;
@define-color color9 #8fd3ff;
@define-color color10 #98c379;
@define-color color11 #e5c07b;
@define-color color12 #87afd7;
@define-color color13 #c3a6ff;
@define-color color14 #9fe0d0;
@define-color color15 #ffffff;
EOF
    warn "pywal unavailable; wrote a default palette to $css (run 'wal -i <image>' later for wallpaper colors)."
}

# The bluetooth module only shows the adapter while bluez is running.
enable_bluetooth() {
    command -v systemctl >/dev/null || return 0
    systemctl is-enabled --quiet bluetooth 2>/dev/null && return 0
    local choice
    read -rp "Enable the Bluetooth service? (Y/n): " choice
    if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
        sudo systemctl enable --now bluetooth || warn "Could not enable bluetooth; run 'sudo systemctl enable --now bluetooth'."
    fi
    return 0
}

restart_waybar() {
    [[ -n "${WAYLAND_DISPLAY:-}" ]] || return 0
    local choice
    if pgrep -x waybar >/dev/null; then
        pkill -x waybar || true
        setsid -f waybar >/dev/null 2>&1 </dev/null
        success "Restarted waybar with the new style."
    else
        read -rp "Start waybar now? (Y/n): " choice
        [[ "${choice:-y}" =~ ^[Yy]$ ]] && setsid -f waybar >/dev/null 2>&1 </dev/null && success "Waybar started."
    fi
    return 0
}

instructions() {
    section "Startup & Keybind"
    cat <<EOF
Add these to your Hyprland config to start waybar at login and toggle it with ALT+A.

${BOLD}~/.config/hypr/hyprland.conf${RESET}
    exec-once = waybar
    bind = ALT, A, exec, pkill -x waybar || waybar

${BOLD}~/.config/hypr/hyprland.lua${RESET} (if you configure Hyprland in Lua)
    hl.on("hyprland.start", function()
        hl.exec_cmd("waybar")
    end)
    hl.bind("ALT + a", hl.dsp.exec_cmd("pkill -x waybar || waybar"))

Then reload Hyprland (hyprctl reload).

Config:   $DEST/config and $DEST/style.css
Colors:   ~/.cache/wal/colors-waybar.css (run 'wal -i <image>' to recolor from a wallpaper)
Restyle:  re-run this installer and pick another style.
EOF
    if [[ -e "$HOME/.config/hypr/utilities/bar.sh" ]]; then
        echo
        warn "The full dotfiles install is present: it already starts the bar (bar.sh) and binds ALT+A, so skip the lines above."
    fi
}

main() {
    section "Waybar Installer"
    [[ -d "$REPO/.config/waybar" ]] || { error "Run this from the Dotfiles repo (InstallScripts/)."; exit 1; }

    select_style
    install_packages
    install_config
    ensure_palette
    enable_bluetooth
    restart_waybar
    success "Waybar installed."
    instructions
}

main "$@"
