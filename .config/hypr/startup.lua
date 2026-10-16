-- Monitors, programs, autostart, and environment variables.

-- Profile defaults; the settings panel overrides them through settings.lua.
local defaults = {
    boot = { enabled = true, black_ms = 100 },
    cursor = { theme = "qogir-manjaro-dark", size = 16 },
}
local saved = require("settings")
local boot = saved.boot or defaults.boot
local cursor = saved.cursor or defaults.cursor

hl.monitor({ output = "eDP-1", mode = "2560x1440@165", position = "0x0", scale = 1.6 })

hl.on("hyprland.start", function()
    if boot.enabled ~= false then
        hl.exec_cmd("BOOT_BLACK_MS=" .. (boot.black_ms or defaults.boot.black_ms) .. " qs -p ~/.config/hypr/utilities/boot --daemonize")
    end
    hl.exec_cmd("hyprctl setcursor " .. (cursor.theme or defaults.cursor.theme) .. " " .. (cursor.size or defaults.cursor.size))
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("~/.config/hypr/utilities/shells.sh start")
    hl.exec_cmd("waybar")
    hl.exec_cmd("pypr")
    hl.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ 0")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("sleep .5 && swww restore")
    hl.exec_cmd("awww-daemon")
end)

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("XCURSOR_SIZE", tostring(cursor.size or defaults.cursor.size))

hl.device({ name = "epic-mouse-v1", sensitivity = 0 })

return { defaults = defaults }
