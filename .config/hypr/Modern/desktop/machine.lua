-- Desktop: everything that differs from the shared Modern/base/ files.
-- A file here named like a base file (e.g. shortcuts.lua) replaces that file for this machine only.

hl.monitor({ output = "DP-4", mode = "1920x1080@74.97", position = "0x0", scale = 1.00, transform = 1 })
hl.monitor({ output = "DP-5", mode = "1920x1080@239.96", position = "1080x416", scale = 1.00 })

return {
    -- Profile defaults; the settings panel overrides them through settings.lua.
    defaults = {
        boot = { enabled = true, black_ms = 2500 },
        cursor = { theme = "Bibata-Modern-Ice", size = 12 },
    },
    sensitivity = .6,
}
