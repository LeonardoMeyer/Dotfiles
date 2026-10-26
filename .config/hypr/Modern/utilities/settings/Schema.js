.pragma library

function slider(key, label, min, max, step, unit, extra) {
    return Object.assign({ type: "slider", key: key, label: label, min: min, max: max, step: step, unit: unit || "" }, extra)
}
function toggle(key, label, extra) {
    return Object.assign({ type: "toggle", key: key, label: label }, extra)
}
function choice(key, label, options, extra) {
    return Object.assign({ type: "choice", key: key, label: label, options: options }, extra)
}
function color(key, label, extra) {
    return Object.assign({ type: "color", key: key, label: label }, extra)
}
function section(label, controls) {
    return { label: label, controls: controls }
}
function opt(v, l, extra) {
    return Object.assign({ v: v, l: l }, extra)
}

var ON = { eq: true }
var WINDOWS = { key: "config.plugin.hyprglass.enabled", eq: true }
var LAYER_KEYS = ["hyprglass.layers", "hyprglass.quickshell"]
var LAYERS = { any: [{ key: "hyprglass.layers", eq: true }, { key: "hyprglass.quickshell", eq: true }] }
var GLASS = { any: [WINDOWS, { key: "hyprglass.layers", eq: true }, { key: "hyprglass.quickshell", eq: true }] }
// "" follows the window preset
var PRESET_OPTIONS = [opt("", "Same as windows", { dflt: true }), opt("apple_extreme", "Apple extreme"),
    opt("glass", "Glass"), opt("pomme", "Pomme"), opt("clear", "Clear"), opt("subtle", "Subtle"), opt("high_contrast", "High contrast")]

function glass(controls) {
    return controls.map(function (c) { c.cap = "hyprglass"; return c })
}
var NOT_THEME = { key: "animation.preset", ne: "theme" }

var PAGES = [
    {
        id: "profile", label: "Profile", icon: "\uf108",
        sections: [
            section("Style", [{ type: "profile" }]),
            section("Saved profiles", [{ type: "saved" }]),
            section("Bar", [{ type: "bar" }, { type: "waybar" }])
        ]
    },
    {
        id: "colors", label: "Colors", icon: "\uf1fc",
        wheel: true,
        sections: []
    },
    {
        id: "windows", label: "Windows", icon: "\uf2d0",
        sections: [
            section("Spacing", [
                slider("config.general.gaps_in", "Inner gaps", 0, 30, 1, " px"),
                slider("config.general.gaps_out", "Outer gaps", 0, 60, 1, " px"),
                slider("config.general.gaps_workspaces", "Workspace gaps", 0, 60, 1, " px")
            ]),
            section("Borders", [
                slider("config.general.border_size", "Border width", 0, 8, 1, " px"),
                slider("config.decoration.rounding", "Corner rounding", 0, 30, 1, " px"),
                slider("config.decoration.rounding_power", "Corner smoothness", 2, 8, 0.5, "", { when: { key: "config.decoration.rounding", gt: 0 } })
            ]),
            section("Border gradient", [
                toggle("border.gradient", "Gradient border", { raises: { key: "config.general.border_size", min: 2 } }),
                choice("border.palette", "Colors", [
                    opt("accent", "Accent", { stops: [9, 13] }), opt("ocean", "Ocean", { stops: [9, 12, 14] }),
                    opt("ember", "Ember", { stops: [1, 3] }), opt("aurora", "Aurora", { stops: [2, 6, 4] }),
                    opt("sunset", "Sunset", { stops: [1, 5, 13] }), opt("glow", "Glow", { stops: [9, 15] })],
                    { when: { key: "border.gradient", eq: true } }),
                slider("border.angle", "Angle", 0, 360, 5, "°", { when: { key: "border.gradient", eq: true } })
            ]),
            section("Tiling", [
                choice("config.general.layout", "Layout", [opt("dwindle", "Dwindle"), opt("master", "Master")]),
                toggle("config.dwindle.preserve_split", "Keep split direction", { when: { key: "config.general.layout", eq: "dwindle" } }),
                toggle("config.dwindle.smart_split", "Split toward the cursor", { when: { key: "config.general.layout", eq: "dwindle" } }),
                toggle("config.dwindle.smart_resizing", "Smart resizing", { when: { key: "config.general.layout", eq: "dwindle" } }),
                slider("config.dwindle.default_split_ratio", "Default split ratio", 0.2, 1.8, 0.05, "", { when: { key: "config.general.layout", eq: "dwindle" } }),
                choice("config.dwindle.force_split", "New window opens", [
                    opt(0, "Follow mouse"), opt(1, "Left / top"), opt(2, "Right / bottom")], { when: { key: "config.general.layout", eq: "dwindle" } }),
                slider("config.master.mfact", "Master size", 0.1, 0.9, 0.05, "", { when: { key: "config.general.layout", eq: "master" } }),
                choice("config.master.orientation", "Master position", [
                    opt("left", "Left"), opt("right", "Right"), opt("top", "Top"), opt("bottom", "Bottom"), opt("center", "Center")],
                    { when: { key: "config.general.layout", eq: "master" } }),
                choice("config.master.new_status", "New windows become", [
                    opt("slave", "Stack"), opt("master", "Master")], { when: { key: "config.general.layout", eq: "master" } })
            ]),
            section("Opacity", [
                slider("config.decoration.active_opacity", "Active windows", 0.3, 1, 0.01),
                slider("config.decoration.inactive_opacity", "Inactive windows", 0.3, 1, 0.01),
                slider("config.decoration.fullscreen_opacity", "Fullscreen windows", 0.3, 1, 0.01)
            ]),
            section("Behavior", [
                toggle("config.general.resize_on_border", "Resize from borders"),
                slider("config.general.extend_border_grab_area", "Border grab area", 0, 40, 1, " px", { when: { key: "config.general.resize_on_border", eq: true } }),
                toggle("config.general.snap.enabled", "Snap floating windows"),
                slider("config.general.snap.window_gap", "Snap to windows within", 1, 40, 1, " px", { when: { key: "config.general.snap.enabled", eq: true } }),
                slider("config.general.snap.monitor_gap", "Snap to edges within", 1, 40, 1, " px", { when: { key: "config.general.snap.enabled", eq: true } }),
                toggle("config.misc.focus_on_activate", "Focus windows that ask"),
                toggle("config.binds.workspace_back_and_forth", "Same workspace key goes back"),
                toggle("config.misc.close_special_on_empty", "Close empty scratchpads"),
                choice("config.input.focus_on_close", "Focus after closing", [opt(0, "Next window"), opt(1, "Under cursor")])
            ])
        ]
    },
    {
        id: "effects", label: "Effects", icon: "\uf0d0",
        sections: [
            section("Blur", [
                toggle("config.decoration.blur.enabled", "Background blur"),
                slider("config.decoration.blur.size", "Size", 1, 20, 1, "", { when: { key: "config.decoration.blur.enabled", eq: true } }),
                slider("config.decoration.blur.passes", "Passes", 1, 8, 1, "", { when: { key: "config.decoration.blur.enabled", eq: true } }),
                slider("config.decoration.blur.vibrancy", "Vibrancy", 0, 1, 0.05, "", { when: { key: "config.decoration.blur.enabled", eq: true } }),
                slider("config.decoration.blur.brightness", "Brightness", 0.2, 1.5, 0.05, "", { when: { key: "config.decoration.blur.enabled", eq: true } }),
                slider("config.decoration.blur.contrast", "Contrast", 0.2, 1.5, 0.05, "", { when: { key: "config.decoration.blur.enabled", eq: true } }),
                slider("config.decoration.blur.noise", "Grain", 0, 0.1, 0.005, "", { when: { key: "config.decoration.blur.enabled", eq: true } }),
                toggle("config.decoration.blur.xray", "X-ray (blur the wallpaper only)", { when: { key: "config.decoration.blur.enabled", eq: true } }),
                toggle("config.decoration.blur.popups", "Blur menus and popups", { when: { key: "config.decoration.blur.enabled", eq: true } })
            ]),
            section("Shadow", [
                toggle("config.decoration.shadow.enabled", "Drop shadow"),
                slider("config.decoration.shadow.range", "Range", 0, 60, 1, " px", { when: { key: "config.decoration.shadow.enabled", eq: true } }),
                slider("config.decoration.shadow.render_power", "Falloff", 1, 4, 1, "", { when: { key: "config.decoration.shadow.enabled", eq: true } }),
                slider("config.decoration.shadow.scale", "Scale", 0.5, 1, 0.05, "", { when: { key: "config.decoration.shadow.enabled", eq: true } }),
                toggle("config.decoration.shadow.sharp", "Hard edges", { when: { key: "config.decoration.shadow.enabled", eq: true } })
            ]),
            section("Glow", [
                toggle("config.decoration.glow.enabled", "Window glow"),
                slider("config.decoration.glow.range", "Range", 0, 60, 1, " px", { when: { key: "config.decoration.glow.enabled", eq: true } }),
                slider("config.decoration.glow.render_power", "Falloff", 1, 4, 1, "", { when: { key: "config.decoration.glow.enabled", eq: true } })
            ]),
            section("Focus", [
                toggle("config.decoration.dim_inactive", "Dim inactive windows"),
                slider("config.decoration.dim_strength", "Dim strength", 0, 1, 0.05, "", { when: { key: "config.decoration.dim_inactive", eq: true } }),
                toggle("config.decoration.motion_blur.enabled", "Motion blur")
            ]),
            section("Glass", glass([
                toggle("config.plugin.hyprglass.enabled", "Glass on windows"),
                toggle("hyprglass.layers", "Glass on layers (other apps' bars and popups)"),
                toggle("hyprglass.quickshell", "Glass on Quickshell"),
                choice("config.plugin.hyprglass.default_theme", "Theme", [opt("dark", "Dark"), opt("light", "Light")], { when: GLASS })
            ])),
            section("Glass blur", glass([
                slider("glass.blur_strength", "Blur (× 12 px)", 0, 30, 0.1, "", { when: GLASS }),
                slider("glass.blur_iterations", "Blur passes", 1, 5, 1, "", { when: GLASS }),
                slider("glass.noise_strength", "Grain", 0, 10, 0.01, "", { when: GLASS }),
                slider("glass.glass_opacity", "Opacity", 0, 1, 0.01, "", { when: GLASS }),
                slider("glass.frost", "Frost over windows", 0, 1, 0.01, "", { when: GLASS }),
                slider("glass.frost_blur", "Frost blur", 0, 10, 0.1, "", { when: [GLASS, { key: "glass.frost", gt: 0 }] }),
                slider("glass.self_sample", "Show own content", 0, 1, 0.01, "", { when: GLASS }),
                toggle("glass.xray", "X-ray (wallpaper only)", { when: GLASS })
            ])),
            section("Glass refraction", glass([
                slider("glass.refraction_strength", "Refraction (× 50 px)", 0, 20, 0.05, "", { when: GLASS }),
                slider("glass.refraction_flow", "Flow (center to edges)", 0, 1, 0.01, "", { when: GLASS }),
                slider("glass.refraction_spread", "Spread (rim to whole)", 0, 1, 0.01, "", { when: GLASS }),
                slider("glass.lens_distortion", "Lens dome", 0, 50, 0.1, "", { when: GLASS }),
                slider("glass.chromatic_aberration", "Rainbow edges", 0, 10, 0.05, "", { when: GLASS })
            ])),
            section("Glass edge", glass([
                slider("glass.edge_thickness", "Edge width (of smaller side)", 0, 0.5, 0.005, "", { when: GLASS }),
                slider("glass.edge_thickness_px", "Edge width in pixels (0 = relative)", 0, 540, 1, " px", { when: GLASS }),
                slider("glass.edge_height", "Lens edge height (0 = soft edge)", 0, 500, 1, " px", { when: GLASS }),
                slider("glass.fresnel_reflection", "Lens edge mirror", 0, 1, 0.01, "", { when: [GLASS, { key: "glass.edge_height", gt: 0 }] }),
                slider("glass.fresnel_strength", "Edge glow", 0, 10, 0.05, "", { when: GLASS }),
                slider("glass.fresnel_tint", "Glow takes background color", 0, 1, 0.01, "", { when: [GLASS, { key: "glass.fresnel_strength", gt: 0 }] }),
                color("glass.fresnel_color", "Glow color", { when: [GLASS, { key: "glass.fresnel_strength", gt: 0 }] })
            ])),
            section("Glass highlights", glass([
                slider("glass.specular_strength", "Highlight", 0, 10, 0.05, "", { when: GLASS }),
                slider("glass.specular_angle", "Highlight angle", 0, 360, 1, "°", { when: [GLASS, { key: "glass.specular_strength", gt: 0 }] }),
                slider("glass.bevel_strength", "Bevel line", 0, 10, 0.05, "", { when: GLASS }),
                slider("glass.bevel_size", "Bevel width", 0, 100, 0.5, " px", { when: [GLASS, { key: "glass.bevel_strength", gt: 0 }] }),
                slider("glass.bevel_angle", "Bevel light angle", 0, 360, 1, "°", { when: [GLASS, { key: "glass.bevel_strength", gt: 0 }] }),
                slider("glass.bevel_shadow", "Bevel shadow", 0, 2, 0.01, "", { when: [GLASS, { key: "glass.bevel_strength", gt: 0 }] }),
                slider("glass.bevel_tint", "Bevel takes background color", 0, 1, 0.01, "", { when: [GLASS, { key: "glass.bevel_strength", gt: 0 }] }),
                color("glass.bevel_color", "Bevel color", { when: [GLASS, { key: "glass.bevel_strength", gt: 0 }] }),
                slider("glass.focus_light", "Active window light", 0, 1, 0.01, "", { when: GLASS }),
                color("glass.focus_light_color", "Active light color", { when: [GLASS, { key: "glass.focus_light", gt: 0 }] })
            ])),
            section("Glass color", glass([
                color("glass.tint_color", "Tint (alpha = strength)", { when: GLASS }),
                slider("glass.brightness", "Brightness", 0, 3, 0.01, "", { when: GLASS }),
                slider("glass.contrast", "Contrast", 0, 3, 0.01, "", { when: GLASS }),
                slider("glass.saturation", "Saturation", 0, 3, 0.01, "", { when: GLASS }),
                slider("glass.vibrancy", "Vibrancy", 0, 5, 0.01, "", { when: GLASS }),
                slider("glass.vibrancy_darkness", "Vibrancy holds off darks", 0, 10, 0.05, "", { when: GLASS }),
                slider("glass.adaptive_dim", "Dim bright backgrounds", 0, 1, 0.01, "", { when: GLASS }),
                slider("glass.adaptive_boost", "Lift dark backgrounds", 0, 1, 0.01, "", { when: GLASS })
            ])),
            section("Glass on layers", glass([
                choice("config.plugin.hyprglass.layers.preset", "Preset", PRESET_OPTIONS, { when: LAYERS }),
                choice("config.plugin.hyprglass.layers.mask_mode", "Where glass goes", [opt("auto", "Auto"), opt("region", "Region"), opt("alpha", "Alpha"), opt("contour", "Contour")], { when: LAYERS }),
                slider("config.plugin.hyprglass.layers.mask_threshold", "Alpha cutoff", 0, 1, 0.001, "", { when: LAYERS }),
                slider("config.plugin.hyprglass.layers.mask_feather", "Soft edges", 0, 1, 0.01, "", { when: LAYERS }),
                toggle("config.plugin.hyprglass.layers.manage_blur", "Replace Hyprland blur", { when: LAYERS }),
                toggle("config.plugin.hyprglass.layers.live_resample", "Follow changes behind", { when: LAYERS }),
                slider("config.plugin.hyprglass.layers.live_resample_fps", "Follow rate (0 = uncapped)", 0, 240, 1, " fps", { when: [LAYERS, { key: "config.plugin.hyprglass.layers.live_resample", eq: true }] }),
                toggle("config.plugin.hyprglass.layers.force_live_resample", "Redraw every frame (heavy)", { when: LAYERS })
            ])),
            section("Glass on app subsurfaces", glass([
                toggle("config.plugin.hyprglass.subsurfaces.enabled", "Glass on app subsurfaces", { when: GLASS }),
                choice("config.plugin.hyprglass.subsurfaces.preset", "Preset", PRESET_OPTIONS, { when: [GLASS, { key: "config.plugin.hyprglass.subsurfaces.enabled", eq: true }] }),
                slider("config.plugin.hyprglass.subsurfaces.radius", "Corners (-1 = capsule)", -1, 500, 1, " px", { when: [GLASS, { key: "config.plugin.hyprglass.subsurfaces.enabled", eq: true }] })
            ])),
            section("Glass performance", glass([
                toggle("config.plugin.hyprglass.manage_window_blur", "Turn off Hyprland blur on glass", { when: WINDOWS }),
                toggle("config.plugin.hyprglass.skip_opaque_windows", "Skip glass under opaque windows", { when: WINDOWS }),
                toggle("config.plugin.hyprglass.blur_fold", "Fewer blur passes, same look", { when: GLASS }),
                toggle("config.plugin.hyprglass.windows.background_cache", "Cache window backgrounds", { when: WINDOWS }),
                toggle("config.plugin.hyprglass.windows.live_resample", "Follow changes behind windows", { when: WINDOWS }),
                slider("config.plugin.hyprglass.windows.live_resample_fps", "Follow rate (0 = uncapped)", 0, 240, 1, " fps", { when: [WINDOWS, { key: "config.plugin.hyprglass.windows.live_resample", eq: true }] })
            ])),
            section("Glass debugging", glass([
                choice("config.plugin.hyprglass.debug.mode", "Debug mode", [opt("off", "Off"), opt("hints_only", "Hints only"), opt("gl_work_only", "GL work only")], { when: GLASS }),
                toggle("config.plugin.hyprglass.debug.timers", "GPU timers", { when: GLASS })
            ])),

        ]
    },
    {
        id: "animations", label: "Animations", icon: "\uf0e7",
        sections: [
            section("Motion", [
                toggle("config.animations.enabled", "Animations"),
                toggle("utilities.animations", "Default quickshell animations"),
                { type: "animpreset", when: { key: "config.animations.enabled", eq: true } },
                slider("animation.speed", "Speed", 0.3, 2.5, 0.05, "×", { when: NOT_THEME }),
                choice("animation.window", "Windows", [
                    opt("popin 90%", "Soft pop"), opt("popin 60%", "Deep pop"), opt("slide", "Slide"), opt("gnomed", "Gnome")],
                    { when: NOT_THEME }),
                choice("animation.workspace", "Workspaces", [
                    opt("slide", "Slide"), opt("slidevert", "Slide vertical"), opt("fade", "Fade"),
                    opt("slidefade", "Slide + fade"), opt("slidefadevert", "Slide + fade vertical")], { when: NOT_THEME })
            ]),
            section("Curve", [{ type: "bezier", when: { key: "config.animations.enabled", eq: true } }]),
            section("Details", [
                toggle("config.misc.animate_manual_resizes", "Animate manual resizes"),
                toggle("config.misc.animate_mouse_windowdragging", "Animate window dragging")
            ])
        ]
    },
    {
        id: "input", label: "Input & cursor", icon: "\uf245",
        sections: [
            section("Mouse", [
                slider("config.input.sensitivity", "Sensitivity", -1, 1, 0.05),
                choice("config.input.accel_profile", "Acceleration", [
                    opt("adaptive", "Adaptive", { dflt: true }), opt("flat", "Flat")]),
                choice("config.input.follow_mouse", "Focus follows mouse", [
                    opt(0, "Off"), opt(1, "Always"), opt(2, "On click"), opt(3, "Loose")]),
                toggle("config.input.natural_scroll", "Natural scrolling"),
                slider("config.input.scroll_factor", "Scroll speed", 0.2, 3, 0.1, "×"),
                toggle("config.input.left_handed", "Left-handed")
            ]),
            section("Touchpad", [
                toggle("config.input.touchpad.natural_scroll", "Natural scrolling"),
                toggle("config.input.touchpad.tap_to_click", "Tap to click"),
                toggle("config.input.touchpad.tap_and_drag", "Tap and drag"),
                toggle("config.input.touchpad.disable_while_typing", "Disable while typing"),
                toggle("config.input.touchpad.middle_button_emulation", "Two-button middle click"),
                slider("config.input.touchpad.scroll_factor", "Scroll speed", 0.2, 3, 0.1, "×")
            ].map(function (c) { c.cap = "touchpad"; return c })),
            section("Gestures", [
                toggle("config.gestures.workspace_swipe_invert", "Natural swipe direction"),
                slider("config.gestures.workspace_swipe_distance", "Swipe distance", 100, 700, 10, " px"),
                toggle("config.gestures.workspace_swipe_create_new", "Swipe past the last workspace")
            ].map(function (c) { c.cap = "touchpad"; return c })),
            section("Keyboard", [
                slider("config.input.repeat_rate", "Repeat rate", 5, 80, 1, "/s"),
                slider("config.input.repeat_delay", "Repeat delay", 100, 800, 10, " ms")
            ]),
            section("Cursor look", [
                { type: "cursors" },
                slider("cursor.size", "Size", 12, 48, 2, " px")
            ]),
            section("Cursor behavior", [
                slider("config.cursor.inactive_timeout", "Hide when idle", 0, 15, 1, " s"),
                toggle("config.cursor.hide_on_key_press", "Hide while typing"),
                toggle("config.cursor.no_warps", "Never jump to windows"),
                choice("config.cursor.warp_on_change_workspace", "Jump on workspace change", [
                    opt(0, "Off"), opt(1, "On"), opt(2, "Force")]),
                choice("config.cursor.no_hardware_cursors", "Software cursor", [
                    opt(2, "Auto"), opt(0, "Never"), opt(1, "Always")]),
                slider("config.cursor.zoom_factor", "Screen magnifier", 1, 4, 0.25, "×")
            ])
        ]
    },
    {
        id: "system", label: "System", icon: "\uf013",
        sections: [
            section("Startup", [
                toggle("boot.enabled", "Boot screen"),
                slider("boot.black_ms", "Boot screen delay", 0, 5000, 100, " ms", { when: { key: "boot.enabled", eq: true } })
            ]),
            section("Display", [
                choice("config.misc.vrr", "Variable refresh rate", [opt(0, "Off"), opt(1, "On"), opt(2, "Fullscreen")]),
                toggle("config.debug.vfr", "Save power when idle"),
                choice("config.render.direct_scanout", "Direct scanout", [opt(0, "Off"), opt(1, "On"), opt(2, "Auto")]),
                toggle("config.debug.overlay", "Show FPS overlay")
            ]),
            section("Behavior", [
                toggle("config.misc.middle_click_paste", "Middle-click paste"),
                toggle("config.misc.mouse_move_enables_dpms", "Wake on mouse move"),
                toggle("config.misc.key_press_enables_dpms", "Wake on key press"),
                toggle("config.misc.enable_anr_dialog", "Warn about frozen apps"),
                toggle("config.misc.mouse_move_focuses_monitor", "Mouse moves focus between monitors", { cap: "multimonitor" })
            ])
        ]
    }
];

// saved together, overrides.lua treats a missing one as on
function glassTargets(entries, values) {
    if (!LAYER_KEYS.some(function (k) { return k in entries })) return entries
    var out = Object.assign({}, entries)
    LAYER_KEYS.forEach(function (k) { if (!(k in out)) out[k] = !!values[k] })
    return out
}

function shown(c, values, caps) {
    if (c.cap && !(caps && caps[c.cap])) return false
    if (!c.when) return true
    // QML hands this over as a list wrapper, not an Array
    var conds = c.when.key === undefined && c.when.any === undefined ? c.when : [c.when]
    for (var i = 0; i < conds.length; i++)
        if (!holds(conds[i], values)) return false
    return true
}

function holds(w, values) {
    if (w.any !== undefined) {
        for (var i = 0; i < w.any.length; i++)
            if (holds(w.any[i], values)) return true
        return false
    }
    var v = values[w.key]
    if (v === undefined || v === null) return false
    if (w.eq !== undefined) {
        if (typeof w.eq === "boolean") return !!v === w.eq
        return v === w.eq
    }
    if (w.ne !== undefined) return v !== w.ne
    if (w.gt !== undefined) return v > w.gt
    return !!v
}

function keys() {
    var out = ["cursor.theme", "animation.curve", "animation.preset"];
    PAGES.forEach(function (p) {
        p.sections.forEach(function (s) {
            s.controls.forEach(function (c) { if (c.key) out.push(c.key); });
        });
    });
    return out;
}

var PRESETS = {
    calm: { curve: [0.16, 1, 0.3, 1], speed: 0.6, window: "popin 90%", workspace: "slide" },
    balanced: { curve: [0.15, 0.85, 0.25, 1], speed: 1, window: "popin 90%", workspace: "slide" },
    snappy: { curve: [0.3, 1, 0.4, 1], speed: 1.7, window: "popin 60%", workspace: "slide" },
    bouncy: { curve: [0.34, 1.56, 0.64, 1], speed: 1, window: "popin 60%", workspace: "slidefade" }
}
