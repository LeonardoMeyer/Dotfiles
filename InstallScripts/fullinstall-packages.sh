#!/bin/bash

# Keep the package manifest in one place so installers and maintenance tools
# agree on which packages belong to the dotfiles setup.
CORE_PACKAGES=(
    python-pywal16 awww waybar starship myfetch neovim python-pywalfox
    hypridle hyprpicker hyprshot hyprlock hyprmon pacman-contrib pyprland fd
    cava brightnessctl otf-code-new-roman nwg-look qogir-icon-theme
    materia-gtk-theme illogical-impulse-bibata-modern-classic-bin
    thunar gvfs tumbler eza bottom htop libreoffice-fresh yazi lazygit hyprdvd quickshell unzip zip
)

OPTIONAL_PACKAGES=(
    spotify-launcher ncspot
    discord visual-studio-code-bin clock-rs-git asciiquarium
)

INSTALLER_PACKAGES=(
    blueman bluez pipewire pipewire-pulse pipewire-alsa pipewire-jack pavucontrol pulsemixer gnome-network-displays gst-plugins-bad reflector rsync
)

FULLINSTALL_PACKAGES=("${CORE_PACKAGES[@]}" "${OPTIONAL_PACKAGES[@]}" "${INSTALLER_PACKAGES[@]}")
