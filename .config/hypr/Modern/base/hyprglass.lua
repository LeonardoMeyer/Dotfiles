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
-- The look of every glassed window. Exported so the settings panel can show these
-- values and overrides.lua can layer the panel's tweaks on top of them.
local PRESET = "apple_extreme"
local PRESET_VALUES = {
    inherits = "glass",

    noise_strength = 0.27,
    blur_iterations = 2,
    blur_strength = 2.3,
    glass_opacity = 1.0,

    refraction_strength = 5.0,
    refraction_flow = 0.03,
    refraction_spread = 0.12,
    lens_distortion = 6.4,
    chromatic_aberration = 0.5,

    edge_thickness = 0.045,
    edge_thickness_px = 33.0,
    edge_height = 0.0,           -- (default)
    bevel_strength = 0,
    bevel_size = 6.0,            -- (default)
    bevel_color = 0xffffff00,    -- (default)
    bevel_tint = 0.0,            -- (default)
    bevel_angle = 315.0,         -- (default)
    bevel_shadow = 0.0,          -- (default)

    fresnel_strength = 0.0,
    fresnel_tint = 0.0,          -- (default)
    fresnel_color = 0xffffff00,  -- (default)
    fresnel_reflection = 0.0,    -- (default)
    specular_strength = 0.0,
    specular_angle = 0.0,        -- (default)

    -- pywal color4 at ~16% strength (last byte is alpha)
    -- tint_color = tint(read_wal_color(4, 0xB8DFFF), 0x14),
    tint_color = 0x50423933,

    self_sample = 0.0,           -- (default)
    xray = 0,                    -- (default)
    focus_light = 0.0,           -- (default)
    focus_light_color = 0xffffff00, -- (default)
    frost = 0.0,                 -- (default)
    frost_blur = 10.0,

    brightness = 1.27,
    contrast = 1.32,
    saturation = 0.4,

    dark = {
        vibrancy = 1.59,
        vibrancy_darkness = 0.0, -- (default)
        adaptive_dim = 0.21,
        adaptive_boost = 0.0,    -- (default)
    },
    light = {
        vibrancy = 1.59,
        vibrancy_darkness = 0.0, -- (default)
        adaptive_dim = 0.21,
        adaptive_boost = 0.0,
    },
}

--[[ Reference: everything else hyprglass understands

Every look option (blur_strength ... frost_blur, brightness ... adaptive_boost) can go
in four places: hg.config({...}) globally, hg.config({ dark = {...}, light = {...} })
per theme, a preset's shared values, or a preset's dark = {...} / light = {...}.
Resolution: preset theme variant -> preset shared -> inherited preset -> theme -> global.

Built-in presets (usable as default_preset, inherits, or layer preset):
    "high_contrast", "subtle", "clear", "glass", "pomme"  ("default" = no preset)

Per-window tags (window rules):
    hl.window_rule({ match = { class = "mpv" }, tag = "+hyprglass_disabled" })
    +hyprglass_enabled            force glass on (useful with enabled = false)
    +hyprglass_disabled           force glass off (wins over enabled)
    +hyprglass_theme_dark         / +hyprglass_theme_light
    +hyprglass_preset_<name>      use another preset for this window

On the fly:
    hyprctl keyword plugin:hyprglass:<option> <value>
    hyprctl dispatch tagwindow +hyprglass_preset_subtle
    hyprctl hyprglass stats       cache hits/misses per monitor
    hyprctl configerrors          unknown options

Layer shape: shape = { inset = 6, radius = -1 } (pill), or
             shape = { inset = { top, right, bottom, left }, radius = 16 }
--]]

if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    -- Resolution order for every look option:
    --   preset (theme variant -> shared -> inherited) -> theme (dark/light) -> global -> built-in default
    -- So values in the apple_extreme preset below win over the globals here.
    hg.config({
        -- Global-only settings
        enabled = false,
        manage_window_blur = true,   -- auto-set noblur on glassed windows
        skip_opaque_windows = true,  -- skip glass under opaque windows (saves GPU)
        blur_fold = true,            -- fewer blur passes, same look
        default_theme = "light",     -- "dark" | "light"
        default_preset = PRESET,

        -- Overridable look settings (defaults unless noted)
        blur_strength = 2.0,         -- radius = value * 12px
        blur_iterations = 2,         -- 1-5 (default 3)
        noise_strength = 0.1,        -- frosted grain 0-1 (default 0.0)
        refraction_strength = 0.6,
        refraction_flow = 0.0,       -- 0 toward center, 1 along edges
        refraction_spread = 1.0,     -- 1 whole window, 0 rim only
        chromatic_aberration = 0.5,
        fresnel_strength = 0.6,      -- edge glow
        fresnel_tint = 0.0,          -- 0 white, 1 colors behind glass
        fresnel_color = 0xffffff00,  -- RRGGBBAA, alpha = how much it replaces white
        fresnel_reflection = 0.0,    -- lens edge mirror, needs edge_height
        specular_strength = 0.8,
        specular_angle = 0.0,        -- degrees, 0 = top, clockwise
        bevel_strength = 0.0,
        bevel_size = 6.0,            -- logical px
        bevel_color = 0xffffff00,
        bevel_tint = 0.0,
        bevel_angle = 315.0,
        bevel_shadow = 0.0,
        glass_opacity = 1.0,
        edge_thickness = 0.06,       -- fraction of smallest side (0-0.15)
        edge_thickness_px = 0.0,     -- >0 replaces edge_thickness
        edge_height = 0.0,           -- >0 turns edge into a lens (0-60)
        tint_color = 0x8899aa22,     -- RRGGBBAA, alpha = tint strength
        lens_distortion = 0.5,       -- center dome magnification
        self_sample = 0.0,           -- mix window's own content in (windows only)
        xray = 0,                    -- 1 = only wallpaper shows through
        focus_light = 0.0,           -- edge light on active window (windows only)
        focus_light_color = 0xffffff00,
        frost = 0.0,                 -- extra blur where windows are behind (windows only)
        frost_blur = 3.0,            -- extra frost blur, in blur_strength units

        -- Per-theme defaults (these have no global default)
        dark = {
            brightness = 0.82,
            contrast = 0.90,
            saturation = 0.80,
            vibrancy = 0.15,
            vibrancy_darkness = 0.0,
            adaptive_dim = 0.4,
            adaptive_boost = 0.0,
        },
        light = {
            brightness = 1.12,
            contrast = 0.92,
            saturation = 0.85,
            vibrancy = 0.12,
            vibrancy_darkness = 0.0,
            adaptive_dim = 0.0,
            adaptive_boost = 0.4,
        },

        layers = {
            enabled = false,
            -- preset = "",              -- preset for all layers (default: default_preset)
            mask_threshold = 0.136,      -- alpha cutoff, per-layer value wins
            mask_mode = "auto",          -- "auto" | "region" | "alpha" | "contour"
            mask_feather = 0.22,         -- soft edge over this much alpha
            live_resample = true,        -- re-render when content behind changes
            live_resample_fps = 30,      -- 0 = uncapped
            force_live_resample = false, -- re-render every frame (heavy)
            manage_blur = true,          -- replace Hyprland blur on glassed layers
        },

        windows = {
            background_cache = true,
            live_resample = true,
            live_resample_fps = 100,     -- 0 = uncapped
        },

        subsurfaces = {
            enabled = false,
            -- preset = "",              -- falls back to layers.preset, then default_preset
            radius = -1,                 -- corner radius px, -1 = capsule
        },
    })

    -- Unset values here fall through to the built-in "glass" preset; the
    -- ones marked (glass) / (default) are those inherited values, spelled out.
    -- The settings panel's Glass sliders are layered over this preset by overrides.lua.
    hg.preset(PRESET, PRESET_VALUES)

    -- Per-layer fields: preset, mask_threshold, mask_mode, mask_feather,
    -- live_resample, exclude, shape = { inset = px | {t, r, b, l}, radius = px | -1 }
    hg.layer("settings-panel", {
        preset = PRESET,
        mask_threshold = 0.01,
        mask_mode = "auto",
        mask_feather = 0.0,
        live_resample = true,
        exclude = false,
        -- shape = { inset = 0, radius = 0 },  -- unset = whole layer
    })

    hg.layer("app-drawer", {
        preset = PRESET,
        mask_threshold = 0.01,
        mask_mode = "auto",
        mask_feather = 0.0,
        live_resample = true,
        exclude = false,
        -- shape = { inset = 0, radius = 0 },  -- unset = whole layer
    })

    hg.layer("music-player", {
        preset = PRESET,
        mask_threshold = 0.01,
        mask_mode = "auto",
        mask_feather = 0.0,
        live_resample = true,
        exclude = false,
        -- shape = { inset = 0, radius = 0 },  -- unset = whole layer
    })
end

return { preset = PRESET, values = PRESET_VALUES }
