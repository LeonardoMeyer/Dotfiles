#!/bin/bash
# The quickshell bar on its own: hypr/Modern/utilities/bar and what it imports, copied into a quickshell config of
# its own (~/.config/quickshell/dotfiles-bar, run with `qs -c dotfiles-bar`) with one of the styles in
# hypr/<style>/quickshellbar/<name>/ as its style.json. Nothing else from these dotfiles is needed, and nothing
# points back into the repo, so it keeps working if the repo is moved or deleted. Runs without the full install
# and without any other installer script.

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
NAME="dotfiles-bar"
DEST="$HOME/.config/quickshell/$NAME"
UTIL="$REPO/.config/hypr/Modern/utilities"
STYLE_FILE=""

PACKAGES=(
    quickshell otf-codenewroman-nerd networkmanager bluez bluez-utils blueman
    pipewire pipewire-pulse wireplumber pavucontrol cava curl jq wl-clipboard
    libnotify pacman-contrib kitty hyprpicker
)
# AUR only: installed when an AUR helper is around, otherwise the bar keeps its built-in palette.
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
    section "Quickshell Bar Style"

    local styles=() f i=1 choice
    for f in "$REPO"/.config/hypr/*/quickshellbar/*/config.json; do
        [[ -f "$f" ]] && styles+=("$f")
    done
    [[ ${#styles[@]} -gt 0 ]] || { error "No quickshell bar styles found under $REPO/.config/hypr/."; exit 1; }

    for f in "${styles[@]}"; do
        # <style>/quickshellbar/<name>/config.json → "Modern — default"
        echo "$i. $(basename "$(dirname "$(dirname "$(dirname "$f")")")") — $(basename "$(dirname "$f")")"
        ((i += 1))
    done
    echo "   (previews: $REPO/.config/hypr/<style>/quickshellbar/<name>/preview.svg)"

    read -rp "Choose a style [1]: " choice
    choice="${choice:-1}"
    [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#styles[@]})) ||
        { error "Invalid style."; exit 1; }

    STYLE_FILE="${styles[$((choice - 1))]}"
    success "Selected $(basename "$(dirname "$STYLE_FILE")")"
}

# ── Config ─────────────────────────────────────────────────────────────────

install_config() {
    section "Installing the Quickshell Bar"

    if [[ -e "$DEST" && ! -e "$DEST/style.json" ]]; then
        local backup="$DEST.backup_$(date +%Y%m%d_%H%M%S)"
        mv "$DEST" "$backup"
        warn "Moved the old $DEST to $backup"
    fi
    # Replaced whole (keeping nothing but the folder), so files dropped from the repo don't linger.
    rm -rf "$DEST"
    mkdir -p "$DEST/music" "$DEST/styles"

    # The same host the full install uses: it loads every <folder>/shell.qml beside it, here only the bar's.
    cp "$REPO/.config/hypr/utilities/shell.qml" "$DEST/shell.qml"
    cp -a "$UTIL/bar" "$UTIL/common" "$DEST/"
    # The bar's waveform reads the music player's cava settings; only the settings are needed, not the player.
    cp "$UTIL/music/cava.conf" "$DEST/music/cava.conf"
    # The color picker, for when waybar (which normally carries it) isn't installed.
    cp "$REPO/.config/waybar/scripts/colorpicker.sh" "$DEST/colorpicker.sh"
    chmod +x "$DEST/colorpicker.sh" "$DEST/common/spotify.sh"

    # Every style, so switching is just copying another one over style.json (the bar picks it up at once).
    local f
    for f in "$REPO"/.config/hypr/*/quickshellbar/*/config.json; do
        cp "$f" "$DEST/styles/$(basename "$(dirname "$f")").json"
    done
    cp "$STYLE_FILE" "$DEST/style.json"

    success "Installed to $DEST"
}

# The bar takes its colors from ~/.cache/wal/colors.json, and keeps a built-in dark palette without it.
ensure_palette() {
    local json="$HOME/.cache/wal/colors.json" wallpaper="$REPO/wallpapers/pywallpaper.jpg"

    [[ -f "$json" ]] && { success "Using your existing pywal palette."; return; }

    if command -v wal >/dev/null && [[ -f "$wallpaper" ]]; then
        info "Generating a pywal palette from the default wallpaper."
        # -n: leave the wallpaper alone; -s -t: don't recolor open terminals.
        wal -q -n -s -t -i "$wallpaper" || true
    fi
    if [[ -f "$json" ]]; then
        success "Pywal palette generated."
    else
        warn "No pywal palette; the bar uses its built-in colors (run 'wal -i <image>' later for wallpaper colors)."
    fi
}

# Wi-Fi and Bluetooth pages talk to NetworkManager and bluez; audio to PipeWire.
enable_services() {
    command -v systemctl >/dev/null || return 0
    local unit choice

    for unit in NetworkManager bluetooth; do
        systemctl is-enabled --quiet "$unit" 2>/dev/null && continue
        read -rp "Enable the $unit service (used by the bar's network page)? (Y/n): " choice
        if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
            sudo systemctl enable --now "$unit" || warn "Could not enable $unit; run 'sudo systemctl enable --now $unit'."
        fi
    done
    systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service >/dev/null 2>&1 ||
        warn "Could not start PipeWire for this user; the audio page needs it."
    return 0
}

start_bar() {
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || return 0
    local choice

    if qs list -c "$NAME" 2>/dev/null | grep -q '^Instance'; then
        qs kill -c "$NAME" >/dev/null 2>&1 || true
        sleep 0.3
        qs -c "$NAME" --daemonize >/dev/null 2>&1 </dev/null
        success "Restarted the bar."
        return 0
    fi

    read -rp "Start the bar now? (Y/n): " choice
    if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
        pgrep -x waybar >/dev/null && warn "waybar is running too; stop it (pkill waybar) if you want only this bar."
        qs -c "$NAME" --daemonize >/dev/null 2>&1 </dev/null && success "Bar started."
    fi
    return 0
}

instructions() {
    local ipc="qs -c $NAME ipc call bar" dir="${DEST/#$HOME/\~}"
    section "Startup & Keybinds"
    cat <<EOF
Add these to your Hyprland config to start the bar at login and control it from the keyboard.

${BOLD}~/.config/hypr/hyprland.conf${RESET}
    exec-once = qs -c $NAME
    bind = ALT, A, exec, $ipc toggle          # hide / show the bar
    bind = SUPER, TAB, exec, $ipc overview    # workspace overview
    bind = SUPER, ESCAPE, exec, $ipc close    # close any open page

${BOLD}~/.config/hypr/hyprland.lua${RESET} (if you configure Hyprland in Lua)
    hl.on("hyprland.start", function()
        hl.exec_cmd("qs -c $NAME")
    end)
    hl.bind("ALT + a", hl.dsp.exec_cmd("$ipc toggle"))
    hl.bind("SUPER + TAB", hl.dsp.exec_cmd("$ipc overview"))
    hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("$ipc close"))

Then reload Hyprland (hyprctl reload). For a blurred bar, add a blur layer rule for the namespace "quickshell-bar".

More IPC calls: $ipc menu network|audio|power|workspaces
                $ipc island media|timer|color
Restart:  qs kill -c $NAME; qs -c $NAME --daemonize
Style:    cp $dir/styles/<name>.json $dir/style.json   (applies live)
Colors:   ~/.cache/wal/colors.json (run 'wal -i <image>' to recolor from a wallpaper)
EOF
    if [[ -e "$HOME/.config/hypr/utilities/bar" ]]; then
        echo
        warn "The full dotfiles install is present and already has this bar (bar.sh apply quickshell); running both gives two bars."
    fi
}

main() {
    section "Quickshell Bar Installer"
    [[ -d "$UTIL/bar" ]] || { error "Run this from the Dotfiles repo (InstallScripts/)."; exit 1; }

    select_style
    install_packages
    install_config
    ensure_palette
    enable_services
    start_bar
    success "Quickshell bar installed."
    instructions
}

main "$@"
