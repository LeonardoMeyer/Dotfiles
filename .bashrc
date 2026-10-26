# ~/.bashrc
[[ $- != *i* ]] && return
# Environment
export EDITOR=nvim
export VISUAL=nvim
export NVM_DIR="$HOME/.nvm"
export PATH="$HOME/.npm-global/bin:$PATH"
export wallpaper="$HOME/wallpapers/pywallpaper.jpg"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
myfetch -c 8 -C " █" && eval "$(starship init bash)"
# aliases
alias lsd='eza --icons'
alias grep='grep --color=auto'
alias c='clear'
alias n='nvim'
alias v='nvim'
alias files='yazi'
alias tasks='btm'
alias spot='ncspot'
alias untar='tar -xf'
alias fonts='fc-list -f "%{family}\n"'
# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias Docs='cd "$HOME/Documents" && nvim'
alias Settings='cd "$HOME/.config/hypr" && nvim'
# Package management
alias search='yay -Q | grep'
alias paci='sudo pacman -S'
alias pacr='sudo pacman -Rns'
alias pacs='pacman -Ss'
alias pacq='pacman -Qs'
alias pacinfo='pacman -Qi'
alias pacfiles='pacman -Ql'
alias pacclean='sudo paccache -r'
# rebuild hyprglass after updates
hyprplugins() {
    command -v hyprpm >/dev/null || return 0
    hyprpm list 2>/dev/null | grep -qi hyprglass || return 0
    hyprpm update && hyprpm reload -n >/dev/null
}
pacup() { sudo pacman -Syu "$@" && hyprplugins; }
pacorphans() {
    local packages
    packages=$(pacman -Qdtq) || return
    [[ -z "$packages" ]] && {
        echo "No orphaned packages found."
        return 0
    }
    printf 'Orphaned packages:\n%s\n' "$packages"
    read -r -p "Remove these packages? [y/N] " confirm
    [[ "$confirm" == [yY] ]] && sudo pacman -Rns $packages
}

# System diagnostics
alias ports='ss -tulpn'
alias mem='free -h'
alias disk='df -h'
alias failed='systemctl --failed'
alias journal='journalctl -p 3 -xb'
alias boot='systemd-analyze'
alias gpu='nvidia-smi'
# Git
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline --graph -15'
# Docker
alias docker='sudo docker'
alias start-portainer='docker start portainer'
alias stop-portainer='docker stop portainer'
alias start-docker='sudo systemctl start docker'
alias stop-docker='sudo systemctl stop docker.service docker.socket'
alias restart-docker='sudo systemctl restart docker'
# Hyprland and desktop
alias pool='clear && asciiquarium'
alias f='clear && myfetch -i e -f -c 16 -C "  "'
alias mefetch='clear && myfetch -c 8 -C " █" && eval "$(starship init bash)"'
alias h='dbus-launch Hyprland'
alias wss='hyprdvd -s'
alias hyprrefresh='hyprctl reload'
alias hypr='cd ~/.config/hypr && nvim'
alias bashrc='n .bashrc'
# Power
alias bye='sudo shutdown -h now'
alias loop='sudo reboot'
# Dotfiles
dotpull() { git -C ~/Dotfiles pull && hyprplugins; }
dotpush() {
    local dir=~/Dotfiles msg
    [[ -z "$(git -C "$dir" status --porcelain)" ]] && {
        echo "Nothing to commit."
        return 0
    }
    echo "Files changed:"
    git -C "$dir" status --short
    read -r -p "Commit message (empty to cancel): " msg
    [[ -z "$msg" ]] && {
        echo "Cancelled."
        return 1
    }
    git -C "$dir" add -A && git -C "$dir" commit -m "$msg" && git -C "$dir" push
}
alias InstallDots='~/Dotfiles/InstallScripts/install.sh'
alias reload='source "$HOME/.bashrc"'
alias Dotfiles='cd ~/Dotfiles/ && nvim'
alias UpdateLocal='~/Dotfiles/InstallScripts/apply.sh'
alias Savepro='~/.config/hypr/utilities/save-profile.sh'
alias Nvim='cd ~/.config/nvim/ && nvim'

# error/success sounds, enable with PROMPT_COMMAND='lol'
lol() {
    local status=$?
    if (( status != 0 )); then
        paplay "$HOME/.config/sounds/error.mp3" >/dev/null 2>&1 &
    else
        paplay "$HOME/.config/sounds/good.mp3" >/dev/null 2>&1 &
    fi
}
export PATH="$HOME/.local/bin:$PATH"
