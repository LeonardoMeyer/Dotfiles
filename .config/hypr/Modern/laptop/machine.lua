-- Laptop: everything that differs from the shared Modern/base/ files.
-- A file here named like a base file (e.g. shortcuts.lua) replaces that file for this machine only.

hl.monitor({ output = "eDP-1", mode = "2560x1440@165", position = "0x0", scale = 1.6 })

return {
    -- Profile defaults; the settings panel overrides them through settings.lua.
    defaults = {
        boot = { enabled = true, black_ms = 100 },
        cursor = { theme = "qogir-manjaro-dark", size = 16 },
    },
    sensitivity = .2,
}
