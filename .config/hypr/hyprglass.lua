-- hyprglass.lua

-- Read pywal color N as a 0xRRGGBB number. Tries colors-hyprland first
-- (same file style.lua uses), then the plain ~/.cache/wal/colors file.
-- local function read_wal_color(index, fallback)
--     local home = os.getenv("HOME")
--
--     local f = io.open(home .. "/.cache/wal/colors-hyprland", "r")
--     if f then
--         for line in f:lines() do
--             local idx, value = line:match("%$?color(%d+)%s*=%s*(%S+)")
--             if idx and tonumber(idx) == index then
--                 local hex = value:match("(%x%x%x%x%x%x)")
--                 if hex then
--                     f:close()
--                     return tonumber(hex, 16)
--                 end
--             end
--         end
--         f:close()
--     end
--
--     f = io.open(home .. "/.cache/wal/colors", "r") -- one #RRGGBB per line
--     if f then
--         local n = 0
--         for line in f:lines() do
--             if n == index then
--                 local hex = line:match("(%x%x%x%x%x%x)")
--                 f:close()
--                 if hex then return tonumber(hex, 16) end
--                 return fallback
--             end
--             n = n + 1
--         end
--         f:close()
--     end
--
--     return fallback
-- end
--
-- -- Build a 0xRRGGBBAA number from 0xRRGGBB plus an alpha byte.
-- local function tint(rgb, alpha)
--     return rgb * 256 + alpha
-- end
--
if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    hg.config({
        enabled = false,
        default_theme = "dark",
        default_preset = "apple_extreme",
        blur_iterations = 4,
        noise_strength = 0.5,
        layers = { enabled = false },
    })

    hg.preset("apple_extreme", {
        inherits = "glass",

        noise_strength = 0.5,
        blur_iterations = 3,
        blur_strength = 12.0,
        glass_opacity = 1.0,

        refraction_strength = 2.0,
        refraction_flow = 0.8,
        refraction_spread = 0.35,
        lens_distortion = 12,
        chromatic_aberration = 5,

        edge_thickness = 0.08,
        bevel_strength = 0,

        -- pywal color4 at ~16% strength (last byte is alpha)
        -- tint_color = tint(read_wal_color(4, 0xB8DFFF), 0x14),

        brightness = 1.0,
        contrast = 1,
        saturation = 1,
    })

    hg.layer("settings-panel", {
        preset = "apple_extreme",
        mask_threshold = 0.01,
    })
end
