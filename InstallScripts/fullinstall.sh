
#!/bin/bash
# Dotfiles Installer — EF

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fullinstall-packages.sh"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

info()    { echo -e "${CYAN}${BOLD}[•]${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[!]${RESET} $*"; }
error()   { echo -e "${RED}${BOLD}[✗]${RESET} $*" >&2; }
section() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

DOTFILES_DIR="$HOME/Dotfiles"
HYPRLAND_STYLES=("Modern|Modern" "Modern laptop|Modern Laptop")
HYPRLAND_STYLE_DIR=""

# ── Backups ────────────────────────────────────────────────────────────────

backup_config() {
    local timestamp="$(date +%Y%m%d_%H%M%S)" item src dest backed_up=false

    for item in \
        "$HOME/.config:$HOME/.config_backup_$timestamp" \
        "$HOME/.icons:$HOME/.icons_backup_$timestamp" \
        "$HOME/wallpapers:$HOME/wallpapers_backup_$timestamp"
    do
        src="${item%%:*}"
        dest="${item#*:}"

        if [[ -e "$src" ]]; then
            info "Backing up $src → $dest"
            mkdir -p "$dest"
            cp -a "$src/." "$dest/"
            success "Backed up $(basename "$src")"
            backed_up=true
        else
            warn "$(basename "$src") not found — skipping."
        fi
    done

    $backed_up && success "Backups complete." || warn "Nothing to back up."
}

backup_bashrc() {
    local dest="$HOME/.bashrc_backup_$(date +%Y%m%d_%H%M%S)"

    [[ -f "$HOME/.bashrc" ]] || { warn "~/.bashrc not found."; return; }

    mkdir -p "$dest"
    cp -a "$HOME/.bashrc" "$dest/.bashrc"
    success "Backed up .bashrc to $dest"
}

# ── Hyprland profile ───────────────────────────────────────────────────────

select_hyprland_style() {
    section "Hyprland Style"

    local i=1 style choice
    for style in "${HYPRLAND_STYLES[@]}"; do
        echo "$i. ${style%%|*}"
        ((i += 1))
    done

    read -rp "Choose a style [1]: " choice
    choice="${choice:-1}"

    [[ "$choice" =~ ^[0-9]+$ ]] &&
        ((choice >= 1 && choice <= ${#HYPRLAND_STYLES[@]})) ||
        { error "Invalid style."; return 1; }

    style="${HYPRLAND_STYLES[$((choice - 1))]}"
    HYPRLAND_STYLE_DIR="${style#*|}"

    [[ -d "$DOTFILES_DIR/.config/hypr/$HYPRLAND_STYLE_DIR" ]] ||
        { error "Profile not found: $HYPRLAND_STYLE_DIR"; return 1; }

    success "Selected ${style%%|*}"
}

# ── Apply dotfiles ─────────────────────────────────────────────────────────

fix_wofi_paths() {
    local dir="$HOME/.config/wofi" file

    [[ -d "$dir" ]] || { warn "Wofi config not found."; return; }

    find "$dir" -maxdepth 1 -type f -name '*.css' -print0 |
    while IFS= read -r -d '' file; do
        sed -i -E \
            "s|/home/[^/]+/\.cache/wal/colors-waybar\.css|$HOME/.cache/wal/colors-waybar.css|g" \
            "$file"
    done
}

apply_dotfiles() {
    section "Applying Dotfiles"

    # Mirror: remove the destination first so stray local files don't survive
    rm -rf "$HOME/wallpapers" "$HOME/.icons"
    cp -a "$DOTFILES_DIR/wallpapers" "$HOME/"
    cp -a "$DOTFILES_DIR/.icons" "$HOME/"
    mkdir -p "$HOME/.config"

    local entry src="$DOTFILES_DIR/.config" dest="$HOME/.config"
    for entry in "$src/"*; do
        [[ -e "$entry" ]] || continue
        [[ "$(basename "$entry")" == hypr ]] && continue
        [[ "$(basename "$entry")" == archive ]] && continue
        rm -rf "$dest/$(basename "$entry")"
        cp -a "$entry" "$dest/"
    done

    src="$DOTFILES_DIR/.config/hypr"
    dest="$HOME/.config/hypr"
    rm -rf "$dest"
    mkdir -p "$dest" "$dest/utilities"

    for entry in hypridle.conf hyprlock.conf; do
        cp -a "$src/$entry" "$dest/"
    done
    cp -a "$src/utilities/." "$dest/utilities/"

    local profile utility file relative
    declare -A profile_utility_paths=()

    for profile in "$src"/*/; do
        [[ -d "$profile" ]] || continue
        cp -a "$profile" "$dest/"

        utility="$profile/utilities"
        [[ -d "$utility" ]] || continue

        while IFS= read -r -d '' file; do
            relative="${file#"$utility"/}"
            profile_utility_paths["$relative"]=1
        done < <(find "$utility" -type f -print0)
    done

    for relative in "${!profile_utility_paths[@]}"; do
        rm -rf "$dest/utilities/$relative"
    done

    utility="$src/$HYPRLAND_STYLE_DIR/utilities"
    [[ ! -d "$utility" ]] || cp -a "$utility/." "$dest/utilities/"
    cp -a "$src/$HYPRLAND_STYLE_DIR/." "$dest/"
    printf '%s\n' "$HYPRLAND_STYLE_DIR" > "$dest/.active-profile"

    cp -a "$DOTFILES_DIR/.bashrc" "$HOME/"
    fix_wofi_paths
    success "Dotfiles applied."
}

run_wallpaper_selector() {
    local script="$HOME/.config/hypr/utilities/wallpaper.sh"

    if [[ -x "$script" ]]; then
        section "Selecting Wallpaper"
        "$script"
    else
        warn "Wallpaper selector not found."
    fi
}

# ── System setup ───────────────────────────────────────────────────────────

setup_mirrors() {
    section "Updating Pacman Mirrorlist"
    yay -S --needed reflector rsync
    sudo reflector --country US --latest 10 --sort rate \
        --save /etc/pacman.d/mirrorlist
    success "Mirrorlist updated."
}

autologin() {
    local user
    user="$(id -un)"

    sudo pacman -S --needed greetd greetd-tuigreet

    sudo tee /etc/greetd/config.toml >/dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "tuigreet --cmd start-hyprland"
user = "greeter"

[initial_session]
command = "start-hyprland"
user = "$user"
EOF

    sudo systemctl disable getty@tty1.service
    sudo systemctl enable greetd.service
    success "Autologin configured for $user."
}

setup_bluetooth() {
    section "Bluetooth"
    yay -S --needed blueman bluez
    sudo systemctl enable --now bluetooth
    success "Bluetooth enabled."
}

setup_pipewire() {
    section "PipeWire & Audio"
    yay -S --needed pipewire pipewire-pulse pipewire-alsa pipewire-jack \
        pavucontrol pulsemixer gnome-network-displays gst-plugins-bad
    systemctl --user enable --now pipewire.service
    systemctl --user enable --now pipewire-pulse.service
    success "PipeWire configured."
}

optional_packages() {
    local choice
    read -rp "Install optional packages? (Y/n): " choice
    if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
        yay -S --needed "${OPTIONAL_PACKAGES[@]}" ||
            warn "Some optional packages failed."
    fi
}

optional_reboot() {
    local choice
    read -rp "Reboot now? (Y/n): " choice
    if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
        nohup bash -c 'sleep 2; sudo reboot' >/dev/null 2>&1 &
    fi
    return 0
}

finish() {
    success "Installation complete!"
    notify-send "Dotfiles Installed" \
        "Open Terminal with MOD+Q\nHello $USER — Thanks for using my Dotfiles!\n-EF" \
        2>/dev/null || true
}

# ── Boot screen / Plymouth ────────────────────────────────────────────────

boot_screen() {
    local dir="$HOME/.config/hypr/utilities/boot"
    local conf=/etc/mkinitcpio.conf choice path image i attempt
    local images=(/boot/initramfs-*.img)
    local modules=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
    local files=(nvidia nvidia-modeset nvidia-uvm nvidia-drm)
    local missing=()

    [[ $EUID -ne 0 ]] || { error "Run as your normal user."; return 1; }
    read -rp "Boot screen: (1) Install (2) Uninstall: " choice

    case "$choice" in
        1)
            [[ -f "$dir/install.sh" && -f "$dir/retro-modern-arch.script" ]] ||
                { error "Theme files not found."; return 1; }

            [[ -r "$HOME/.cache/wal/colors" &&
                $(grep -c '^#' "$HOME/.cache/wal/colors") -eq 16 ]] ||
                { error "Run wal -i /path/to/wallpaper first."; return 1; }

            command -v yay >/dev/null ||
                { error "Install yay first."; return 1; }

            grep -Eq '^HOOKS=.*[( ]encrypt[ )]' "$conf" &&
                { error "Convert encrypt to sd-encrypt manually."; return 1; }

            yay -S --needed plymouth mkinitcpio python python-pillow python-numpy ||
                { error "Dependency installation failed."; return 1; }

            sudo python - "$conf" <<'PY' || return 1
import re, sys

p = sys.argv[1]
s = open(p).read()

def update(name, transform):
    global s
    s, n = re.subn(
        rf'^{name}=\((.*?)\)',
        lambda m: f'{name}=({" ".join(transform(m.group(1).split()))})',
        s, count=1, flags=re.M
    )
    if not n:
        raise SystemExit(f"Could not find {name} in mkinitcpio.conf")

def modules(items):
    for x in ("nvidia", "nvidia_modeset", "nvidia_uvm", "nvidia_drm"):
        if x not in items:
            items.append(x)
    return items

def hooks(items):
    items = ["systemd" if x == "udev" else
             "sd-vconsole" if x == "keymap" else x
             for x in items if x != "consolefont"]
    if "systemd" not in items:
        raise SystemExit("systemd hook is required")
    if "plymouth" not in items:
        items.insert(items.index("systemd") + 1, "plymouth")
    if "modconf" in items and "kms" not in items:
        items.insert(items.index("modconf") + 1, "kms")
    return items

update("MODULES", modules)
update("HOOKS", hooks)
open(p, "w").write(s)
PY

            if [[ -f /etc/default/grub ]] && command -v grub-mkconfig >/dev/null; then
                sudo sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT="/ {
                    s/(^|[[:space:]])(quiet|splash|systemd\.show_status=[^[:space:]"]+|loglevel=[^[:space:]"]+)([[:space:]]|")/\1/g
                    s/"$/ quiet splash"/
                }' /etc/default/grub
                sudo grub-mkconfig -o /boot/grub/grub.cfg || return 1
            elif compgen -G "/boot/loader/entries/*.conf" >/dev/null; then
                for path in /boot/loader/entries/*.conf; do
                    sudo sed -i -E '/^options/ {
                        s/(^|[[:space:]])(quiet|splash|systemd\.show_status=[^[:space:]]+|loglevel=[^[:space:]]+)([[:space:]]|$)/\1/g
                        s/$/ quiet splash/
                    }' "$path"
                done
            elif [[ -f /etc/kernel/cmdline ]]; then
                sudo sed -i -E 's/(^|[[:space:]])(quiet|splash|systemd\.show_status=[^[:space:]]+|loglevel=[^[:space:]]+)([[:space:]]|$)/\1/g' /etc/kernel/cmdline
                sudo sed -i '1 s/$/ quiet splash/' /etc/kernel/cmdline
            else
                warn "Boot configuration not detected; add quiet splash manually."
            fi

            chmod +x "$dir"/*.sh
            sudo bash "$dir/install.sh" || {
                error "Theme installation failed."
                return 1
            }

            images=(/boot/initramfs-*.img)
            for attempt in 1 2; do
                missing=()
                for image in "${images[@]}"; do
                    [[ -f "$image" ]] || continue
                    for i in "${!modules[@]}"; do
                        lsinitcpio -l "$image" 2>/dev/null |
                            grep -Eq "/${files[i]}\.ko(\.(zst|xz|gz))?$" ||
                            missing+=("$(basename "$image"): ${modules[i]}")
                    done
                done

                ((${#missing[@]} == 0)) && break
                if ((attempt == 1)); then
                    warn "NVIDIA modules missing; rebuilding initramfs..."
                    sudo mkinitcpio -P || warn "Initramfs rebuild failed."
                fi
            done

            if ((${#missing[@]})); then
                warn "NVIDIA modules still missing:"
                printf '  %s\n' "${missing[@]}"
                warn "Check modinfo nvidia and your installed kernel/driver."
            else
                success "NVIDIA modules verified."
            fi
            success "Boot screen installed."
            ;;

        2)
            sudo python - "$conf" <<'PY' || return 1
import re, sys

p = sys.argv[1]
s = open(p).read()
s, n = re.subn(
    r'^HOOKS=\((.*?)\)',
    lambda m: "HOOKS=(" + " ".join(
        x for x in m.group(1).split() if x != "plymouth"
    ) + ")",
    s, count=1, flags=re.M
)
if not n:
    raise SystemExit("Could not find HOOKS in mkinitcpio.conf")
open(p, "w").write(s)
PY

            if [[ -f /etc/default/grub ]] && command -v grub-mkconfig >/dev/null; then
                sudo sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT="/ {
                    s/(^|[[:space:]])(quiet|splash|systemd\.show_status=[^[:space:]"]+|loglevel=[^[:space:]"]+)([[:space:]]|")/\1/g
                    s/"$/ systemd.show_status=1 loglevel=7"/
                }' /etc/default/grub
                sudo grub-mkconfig -o /boot/grub/grub.cfg || return 1
            elif compgen -G "/boot/loader/entries/*.conf" >/dev/null; then
                for path in /boot/loader/entries/*.conf; do
                    sudo sed -i -E '/^options/ {
                        s/(^|[[:space:]])(quiet|splash|systemd\.show_status=[^[:space:]]+|loglevel=[^[:space:]]+)([[:space:]]|$)/\1/g
                        s/$/ systemd.show_status=1 loglevel=7/
                    }' "$path"
                done
            elif [[ -f /etc/kernel/cmdline ]]; then
                sudo sed -i -E 's/(^|[[:space:]])(quiet|splash|systemd\.show_status=[^[:space:]]+|loglevel=[^[:space:]]+)([[:space:]]|$)/\1/g' /etc/kernel/cmdline
                sudo sed -i '1 s/$/ systemd.show_status=1 loglevel=7/' /etc/kernel/cmdline
            else
                warn "Boot configuration not detected."
            fi

            sudo systemctl disable --now plymouth-logfeed.service 2>/dev/null || true
            sudo systemctl disable --now plymouth-quit.service plymouth-quit-wait.service 2>/dev/null || true
            sudo rm -rf /etc/plymouth /usr/share/plymouth
            sudo rm -f /usr/local/bin/plymouth-logfeed /etc/systemd/system/plymouth-logfeed.service
            sudo systemctl daemon-reload

            if pacman -Qq plymouth &>/dev/null; then
                yay -Rns --noconfirm plymouth || return 1
            fi

            sudo mkinitcpio -P || {
                error "Initramfs rebuild failed; fix the error before rebooting."
                return 1
            }

            success "Plymouth removed; verbose boot logging enabled."
            ;;

        *)
            error "Choose 1 or 2."
            return 1
            ;;
    esac
}

# Backwards-compatible name for the standalone boot-screen launcher.
boot_load() { boot_screen "$@"; }

# ── Installation modes ─────────────────────────────────────────────────────

auto_install() {
    section "Automatic Installation"
    
    local choice 
    read -rp "Update mirrorlist? (Y/n): " choice
    [[ "${choice:-y}" =~ ^[Yy]$ ]] && setup_mirrors

    info "Installing core packages..."
    yay -S --needed "${CORE_PACKAGES[@]}"
    sudo systemctl enable --now avahi-daemon

    setup_bluetooth
    setup_pipewire
    apply_dotfiles
    run_wallpaper_selector
    autologin

    local choice
    read -rp "Install Boot Screen? (Y/n): " choice
    if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
        boot_screen || warn "Boot screen setup failed."
    fi

    optional_packages
    optional_reboot
    finish
}

manual_install() {
    section "Manual Installation"

    local choice pkg
    read -rp "Update mirrorlist? (Y/n): " choice
    [[ "${choice:-y}" =~ ^[Yy]$ ]] && setup_mirrors

    section "Package Selection"
    for pkg in "${CORE_PACKAGES[@]}"; do
        read -rp "Install $pkg? (Y/n): " choice
        if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
            yay -S --needed "$pkg" || warn "Failed to install $pkg"
        fi
    done

    read -rp "Install Bluetooth support? (Y/n): " choice
    [[ "${choice:-y}" =~ ^[Yy]$ ]] && setup_bluetooth

    read -rp "Configure PipeWire? (Y/n): " choice
    [[ "${choice:-y}" =~ ^[Yy]$ ]] && setup_pipewire

    apply_dotfiles
    run_wallpaper_selector

    read -rp "Install Boot Screen? (Y/n): " choice
    if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
        boot_screen || warn "Boot screen setup failed."
    fi

    read -rp "Install autologin? (Y/n): " choice
    if [[ "${choice:-y}" =~ ^[Yy]$ ]]; then
        autologin || warn "Autologin setup failed."
    fi

    optional_packages
    optional_reboot
    finish
}

# ── Entry point ─────────────────────────────────────────────────────────────

main() {
    echo -e "${CYAN}${BOLD}"
    cat <<'EOF'
  ____        _    __ _ _
 |  _ \  ___ | |_ / _(_) | ___  ___
 | | | |/ _ \| __| |_| | |/ _ \/ __|
 | |_| | (_) | |_|  _| | |  __/\__ \
 |____/ \___/ \__|_| |_|_|\___||___/
EOF
    echo -e "${RESET}"

    [[ -d "$DOTFILES_DIR" ]] ||
        { error "Dotfiles directory not found: $DOTFILES_DIR"; return 1; }
    command -v yay >/dev/null ||
        { error "Install yay first."; return 1; }

    section "Welcome"
    select_hyprland_style

    local install_choice backup_choice
    read -rp "Installation mode — (A)utomatic or (M)anual? [A]: " install_choice
    install_choice="${install_choice:-a}"

    read -rp "Back up current dotfiles? (Y/n): " backup_choice
    if [[ "${backup_choice:-y}" =~ ^[Yy]$ ]]; then
        backup_config
        backup_bashrc
    fi

    case "${install_choice,,}" in
        a) auto_install ;;
        m) manual_install ;;
        *) error "Unknown option '$install_choice'."; return 1 ;;
    esac
}

# Only run the full installer when executed directly.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi

