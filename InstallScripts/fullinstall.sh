
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

# Symlink ~/<entry> -> repo for every top-level entry, so edits go both ways.
link_entry() {
    local target="$1" link="$2" backup="$3"

    if [[ -L "$link" && "$(readlink -f "$link")" == "$(readlink -f "$target")" ]]; then
        return
    fi
    if [[ -e "$link" || -L "$link" ]]; then
        mkdir -p "$backup"
        mv "$link" "$backup/$(basename "$link")"
        warn "Moved existing $link to $backup/"
    fi
    mkdir -p "$(dirname "$link")"
    ln -s "$target" "$link"
    success "Linked $link -> $target"
}

apply_dotfiles() {
    section "Linking Dotfiles"

    local src="$DOTFILES_DIR/.config" entry name
    local backup="$HOME/.dotfiles_replaced_$(date +%Y%m%d_%H%M%S)"
    local style="$src/hypr/$HYPRLAND_STYLE_DIR"

    shopt -s nullglob dotglob
    for entry in "$src"/*; do
        link_entry "$entry" "$HOME/.config/${entry##*/}" "$backup/.config"
    done
    for name in wallpapers .icons .bashrc; do
        [[ -e "$DOTFILES_DIR/$name" ]] && link_entry "$DOTFILES_DIR/$name" "$HOME/$name" "$backup"
    done
    shopt -u nullglob dotglob

    # The active profile's files overlay hypr/ (written through the symlink into the repo).
    if [[ -n "$HYPRLAND_STYLE_DIR" && -d "$style" ]]; then
        cp -an "$style/utilities/." "$src/hypr/utilities/" 2>/dev/null || true
        find "$style" -mindepth 1 -maxdepth 1 ! -name utilities ! -name hyprlock.conf \
            -exec cp -a {} "$src/hypr/" \;
        echo "$HYPRLAND_STYLE_DIR" > "$src/hypr/.active-profile"
    fi

    fix_wofi_paths
    success "Dotfiles linked."
    nohup bash -c 'sleep 1; hyprctl reload' >/dev/null 2>&1 &
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
    local choice
    local boot_dir="$HOME/Dotfiles/.config/hypr/utilities/boot"
    local installer="$HOME/Dotfiles/.config/hypr/utilities/boot/install.sh"
    local entry="/boot/loader/entries/2026-03-05_23-29-34_linux.conf"
    local mkinit="/etc/mkinitcpio.conf"
    local greetd="/etc/greetd/config.toml"
    local wrapper="/usr/local/bin/start-hyprland-quiet"
    local greetd_dropin="/etc/systemd/system/greetd.service.d/plymouth.conf"
    local greetd_legacy="/etc/systemd/system/greetd.service.d/override.conf"
    local quit_dropin="/etc/systemd/system/plymouth-quit.service.d/override.conf"
    local quit_wait_dropin="/etc/systemd/system/plymouth-quit-wait.service.d/override.conf"

    read -rp "Boot screen: (1) Install/Update (2) Uninstall: " choice

    case "$choice" in
        1) ;;
        2) ;;
        *) echo "Invalid option."; return 1 ;;
    esac

    [[ -d "$boot_dir" ]] || {
        echo "Boot directory not found: $boot_dir"
        return 1
    }

    if [[ "$choice" == 1 && ! -f "$installer" ]]; then
        echo "Theme installer not found: $installer"
        return 1
    fi

    if [[ "$choice" == 1 ]]; then
        # Install or update dependencies; pacman safely skips installed packages.
        sudo pacman -S --needed plymouth mkinitcpio python python-pillow python-numpy || return 1

        # Add hooks/modules idempotently.
        sudo python - "$mkinit" install <<'PY' || return 1
import re, sys
from pathlib import Path

p = Path(sys.argv[1])
s = p.read_text()

def update(name, transform):
    global s
    pat = rf"(?m)^{name}=\(([^)]*)\)\s*$"
    m = re.search(pat, s)
    if not m:
        raise SystemExit(f"Could not find {name}= in {p}")
    values = m.group(1).split()
    values = transform(values)
    s = s[:m.start()] + f"{name}=({' '.join(values)})" + s[m.end():]

def hooks(values):
    values = [v for v in values if v != "plymouth"]
    if "systemd" in values:
        values.insert(values.index("systemd") + 1, "plymouth")
    else:
        values.insert(1 if values and values[0] == "base" else 0, "plymouth")
    return values

def modules(values):
    for name in ("nvidia", "nvidia_modeset", "nvidia_uvm", "nvidia_drm"):
        if name not in values:
            values.append(name)
    return values

update("HOOKS", hooks)
update("MODULES", modules)
p.write_text(s)
PY

        # Install/update the custom theme from the correct directory.
        sudo bash "$installer" || return 1
        sudo plymouth-set-default-theme retro-modern-arch || return 1

        # Normalize the active systemd-boot entry; never append duplicates.
        [[ -f "$entry" ]] || {
            echo "Boot entry not found: $entry"
            return 1
        }

        sudo python - "$entry" install <<'PY' || return 1
import re, sys
from pathlib import Path

p = Path(sys.argv[1])
lines = p.read_text().splitlines()
idx = [i for i, line in enumerate(lines) if re.match(r"^\s*options\s+", line)]
if len(idx) != 1:
    raise SystemExit(f"Expected exactly one options line; found {len(idx)}")

i = idx[0]
tokens = lines[i].split()[1:]
managed = ("quiet", "splash", "plymouth.nolog")
tokens = [
    t for t in tokens
    if t not in managed
    and not t.startswith(("loglevel=", "systemd.show_status=", "rd.udev.log_level="))
]
tokens += [
    "quiet", "splash", "loglevel=3",
    "systemd.show_status=false", "rd.udev.log_level=3"
]
lines[i] = "options " + " ".join(tokens)
p.write_text("\n".join(lines) + "\n")
PY

        # Hide automatic Hyprland startup output. This only applies when greetd
        # has an autologin ([initial_session]); without one, the normal tuigreet
        # (or getty) login prompt on tty1 is left exactly as it is.
        sudo rm -f "$greetd_dropin"
        if [[ -f "$greetd" ]] && grep -q '^\[initial_session\]' "$greetd"; then
            sudo install -d -m 755 /usr/local/bin
            sudo tee "$wrapper" >/dev/null <<'EOF' || return 1
#!/bin/sh
exec start-hyprland >/dev/null 2>&1
EOF
            sudo chmod 755 "$wrapper" || return 1

            sudo python - "$greetd" <<'PY' || return 1
import re, sys
from pathlib import Path

p = Path(sys.argv[1])
s = p.read_text()
pat = r"(?ms)(^\[initial_session\]\s*\n)(.*?)(?=^\[|\Z)"
m = re.search(pat, s)
section = m.group(2)
section, n = re.subn(
    r'(?m)^(\s*command\s*=\s*)"[^"]*"\s*$',
    'command = "/usr/local/bin/start-hyprland-quiet"',
    section, count=1
)
if n != 1:
    raise SystemExit("Could not safely update initial_session command")

p.write_text(s[:m.start(2)] + section + s[m.end(2):])
PY

            sudo install -d -m 755 "$(dirname "$greetd_dropin")"
            sudo tee "$greetd_dropin" >/dev/null <<'EOF'
[Service]
StandardOutput=null
StandardError=null
EOF
        else
            sudo rm -f "$wrapper"
        fi

        # Remove overrides and the log feed from earlier versions; they could
        # leave the splash stuck. getty on tty2-6 is never touched.
        sudo rm -f "$greetd_legacy" "$quit_dropin" "$quit_wait_dropin"
        sudo systemctl disable plymouth-logfeed.service 2>/dev/null || true
        sudo rm -f /etc/systemd/system/plymouth-logfeed.service /usr/local/bin/plymouth-logfeed

        sudo systemctl daemon-reload || return 1
        sudo mkinitcpio -P || return 1

        echo "[✓] Boot screen installed/updated."
        echo "[✓] Boot parameters normalized."
        echo "[✓] Quiet Hyprland startup configured."
        echo "Reboot to test."

    else
        # Undo only what the installer added; other hooks/modules are untouched.
        sudo python - "$mkinit" <<'PY' || return 1
import re, sys
from pathlib import Path

p = Path(sys.argv[1])
s = p.read_text()
drop = {
    "HOOKS": {"plymouth"},
    "MODULES": {"nvidia", "nvidia_modeset", "nvidia_uvm", "nvidia_drm"},
}
for name, remove in drop.items():
    pat = rf"(?m)^{name}=\(([^)]*)\)\s*$"
    m = re.search(pat, s)
    if m:
        values = [v for v in m.group(1).split() if v not in remove]
        s = s[:m.start()] + f"{name}=({' '.join(values)})" + s[m.end():]
p.write_text(s)
PY

        # Remove every parameter this installer manages; the only one left is
        # loglevel=7 (kernel debug output).
        for f in /boot/loader/entries/*.conf; do
            [[ -f "$f" ]] || continue
            sudo python - "$f" <<'PY' || return 1
import re, sys
from pathlib import Path

p = Path(sys.argv[1])
lines = p.read_text().splitlines()
for i, line in enumerate(lines):
    if re.match(r"^\s*options\s+", line):
        tokens = [
            t for t in line.split()[1:]
            if t not in ("quiet", "splash", "plymouth.nolog")
            and not t.startswith(("loglevel=", "systemd.show_status=", "rd.udev.log_level="))
        ]
        lines[i] = "options " + " ".join(tokens + ["loglevel=7"])
p.write_text("\n".join(lines) + "\n")
PY
        done

        # Stock autologin config (same as autologin()).
        if [[ -f "$greetd" ]]; then
            sudo sed -i 's#/usr/local/bin/start-hyprland-quiet#start-hyprland#' "$greetd"
        fi

        sudo rm -f "$wrapper" "$greetd_dropin" "$greetd_legacy" "$quit_dropin" "$quit_wait_dropin"
        sudo rmdir "$(dirname "$greetd_dropin")" "$(dirname "$quit_dropin")" \
            "$(dirname "$quit_wait_dropin")" 2>/dev/null || true

        # Remove the live-log feed and the passwordless theme-rebuild helper.
        sudo systemctl disable plymouth-logfeed.service 2>/dev/null || true
        sudo rm -f /etc/systemd/system/plymouth-logfeed.service \
            /usr/local/bin/plymouth-logfeed /etc/sudoers.d/boot-theme
        sudo rm -rf /usr/local/lib/boot-theme

        # Use the standard text theme before removing the custom theme/package.
        if command -v plymouth-set-default-theme >/dev/null 2>&1; then
            sudo plymouth-set-default-theme text 2>/dev/null || true
        fi

        if [[ -f "$boot_dir/uninstall.sh" ]]; then
            sudo bash "$boot_dir/uninstall.sh" || return 1
        else
            sudo rm -rf /usr/share/plymouth/themes/retro-modern-arch
        fi

        sudo systemctl daemon-reload || return 1
        sudo pacman -Rns --noconfirm plymouth || return 1
        sudo mkinitcpio -P || return 1

        echo "[✓] Plymouth and its custom theme removed."
        echo "[✓] Boot configuration restored; kernel parameters: loglevel=7 only."
    fi
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

