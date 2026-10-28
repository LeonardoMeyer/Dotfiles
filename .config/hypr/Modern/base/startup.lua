local defaults = require("machine").defaults
local saved = require("settings")
local boot = saved.boot or defaults.boot
local cursor = saved.cursor or defaults.cursor

-- Hex: helpers dos plugins do Omarchy no PATH (compat/bin)
local home = os.getenv("HOME")
local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin"
local compat = home .. "/.config/hypr/utilities/compat/bin"
if not path:find(compat, 1, true) then
    hl.env("PATH", compat .. ":" .. home .. "/.local/bin:" .. path)
end

-- Hex: se a tela de bloqueio cair, deixa outro bloqueador assumir
-- (sem isso o Hyprland fica na tela vermelha de "lock crashed")
hl.config({ misc = { allow_session_lock_restore = true } })

hl.on("hyprland.start", function()
    -- Hex: autologin + bloqueio. A primeira coisa da sessão é a tela de
    -- bloqueio do elifouts; se ela falhar (sai com erro), o hyprlock assume,
    -- para a sessão nunca ficar aberta sem senha.
    -- Quem entrou pelo tuigreet (depois do SUPER+M) já digitou a senha:
    -- o greetd marca essa sessão com HEX_SKIPLOCK=1. Sem a marca, bloqueia.
    if os.getenv("HEX_SKIPLOCK") ~= "1" then
        hl.exec_cmd([[sh -c '~/.config/hypr/utilities/lock.sh || hyprlock']])
    end
    if boot.enabled ~= false then
        hl.exec_cmd("BOOT_BLACK_MS=" .. (boot.black_ms or defaults.boot.black_ms) .. " qs -p ~/.config/hypr/utilities/boot --daemonize")
    end
    -- Hex: reaplica a cor do teclado salva no widget Periféricos
    hl.exec_cmd("~/.config/hypr/utilities/plugins/perifericos/bin/hex-perifericos restore")
    hl.exec_cmd("hyprctl setcursor " .. (cursor.theme or defaults.cursor.theme) .. " " .. (cursor.size or defaults.cursor.size))
    -- portal doesn't survive a relog, restart it
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        .. "; systemctl --user reset-failed xdg-desktop-portal-hyprland xdg-desktop-portal"
        .. "; systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("~/.config/hypr/utilities/shells.sh start")
    hl.exec_cmd("~/.config/hypr/utilities/bar.sh boot")
    hl.exec_cmd("~/.config/hypr/utilities/pypr.sh")
    hl.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ 0")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd([[sh -c '
        command -v hyprpm >/dev/null 2>&1 || exit 0
        hyprpm list 2>/dev/null | grep -qi hyprglass || exit 0
        hyprpm reload -n >/dev/null 2>&1
        sleep 1
        hyprctl plugin list 2>/dev/null | grep -qi hyprglass && hyprctl reload
    ']])
end)

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
-- Hex: variáveis da NVIDIA só quando o driver da NVIDIA está carregado
local nv = io.open("/proc/driver/nvidia/version", "r")
if nv then
    nv:close()
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
end
hl.env("XCURSOR_THEME", cursor.theme or defaults.cursor.theme)
hl.env("XCURSOR_SIZE", tostring(cursor.size or defaults.cursor.size))
hl.device({ name = "epic-mouse-v1", sensitivity = 0 })

return { defaults = defaults }
