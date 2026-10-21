#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

clear
echo "======================================"
echo " Dotfiles Installer"
echo "======================================"
echo "1. Full install"
echo "2. Waybar"
echo "3. Wofi (deprecated)"
echo "4. Hyprlock"
echo "5. Neovim"
echo "6. Starship"
echo "7. GTK themes"
echo "8. Autologin"
echo "p. Package manager TUI"
echo "q. Quit"
echo ""
read -rp "Choose an option: " choice

case "${choice,,}" in
    1) target="fullinstall.sh" ;;
    2) target="waybarinstall.sh" ;;
    3) target="wofiinstall.sh" ;;
    4) target="hyprlockinstall.sh" ;;
    5) target="nviminstall.sh" ;;
    6) target="starshipinstall.sh" ;;
    7) target="gtkthemesinstall.sh" ;;
    8) target="autologin-load.sh" ;;
    p) target="../.config/hypr/utilities/package-tui.sh" ;;
    q) echo "Goodbye."; exit 0 ;;
    *) echo "Invalid choice: $choice"; exit 1 ;;
esac

script_path="$SCRIPT_DIR/$target"
if [ ! -f "$script_path" ]; then
    echo "Installer not found: $script_path"
    exit 1
fi

chmod +x "$script_path"
clear
exec "$script_path"
