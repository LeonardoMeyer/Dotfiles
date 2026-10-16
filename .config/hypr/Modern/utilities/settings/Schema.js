.pragma library

// Every page and option of the panel. Keys are dotted paths into settings.lua:
//   config.*  -> hl.config() options (live values come from hyprctl getoption)
//   animation.*, cursor.*, boot.* -> handled by overrides.lua / startup.lua
// Adding an option is one line here.

function slider(key, label, min, max, step, unit) {
    return { type: "slider", key: key, label: label, min: min, max: max, step: step, unit: unit || "" }
}
function toggle(key, label) {
    return { type: "toggle", key: key, label: label }
}
function choice(key, label, options) {
    return { type: "choice", key: key, label: label, options: options }
}
function section(label) {
    return { type: "section", label: label }
}

var PAGES = [
    {
        id: "profile", label: "Profile", icon: "\uf108",
        controls: [{ type: "profile" }]
    },
    {
        id: "colors", label: "Colors", icon: "\uf1fc",
        controls: [{ type: "themes" }]
    },
    {
        id: "windows", label: "Windows", icon: "\uf2d0",
        controls: [
            section("Layout"),
            slider("config.general.gaps_in", "Inner gaps", 0, 30, 1, " px"),
            slider("config.general.gaps_out", "Outer gaps", 0, 60, 1, " px"),
            slider("config.general.border_size", "Border width", 0, 8, 1, " px"),
            slider("config.decoration.rounding", "Corner rounding", 0, 30, 1, " px"),
            choice("config.general.layout", "Layout", [{ v: "dwindle", l: "Dwindle" }, { v: "master", l: "Master" }]),
            toggle("config.dwindle.preserve_split", "Keep split direction"),
            section("Opacity"),
            slider("config.decoration.active_opacity", "Active windows", 0.3, 1, 0.01),
            slider("config.decoration.inactive_opacity", "Inactive windows", 0.3, 1, 0.01),
            section("Behavior"),
            toggle("config.general.resize_on_border", "Resize from borders"),
            toggle("config.general.snap.enabled", "Snap floating windows"),
            toggle("config.misc.focus_on_activate", "Focus windows that ask"),
            toggle("config.misc.enable_swallow", "Swallow terminals")
        ]
    },
    {
        id: "effects", label: "Effects", icon: "\uf0d0",
        controls: [
            section("Blur"),
            toggle("config.decoration.blur.enabled", "Background blur"),
            slider("config.decoration.blur.size", "Blur size", 1, 20, 1),
            slider("config.decoration.blur.passes", "Blur passes", 1, 8, 1),
            slider("config.decoration.blur.vibrancy", "Blur vibrancy", 0, 1, 0.05),
            toggle("config.decoration.blur.xray", "X-ray (blur the wallpaper only)"),
            section("Shadow and glow"),
            toggle("config.decoration.shadow.enabled", "Drop shadow"),
            slider("config.decoration.shadow.range", "Shadow range", 0, 60, 1, " px"),
            slider("config.decoration.shadow.render_power", "Shadow falloff", 1, 4, 1),
            toggle("config.decoration.glow.enabled", "Window glow"),
            slider("config.decoration.glow.range", "Glow range", 0, 60, 1, " px"),
            section("Focus"),
            toggle("config.decoration.dim_inactive", "Dim inactive windows"),
            slider("config.decoration.dim_strength", "Dim strength", 0, 1, 0.05),
            toggle("config.decoration.motion_blur.enabled", "Motion blur")
        ]
    },
    {
        id: "animations", label: "Animations", icon: "\uf0e7",
        controls: [
            toggle("config.animations.enabled", "Animations"),
            choice("animation.preset", "Style", [
                { v: "theme", l: "Profile" }, { v: "calm", l: "Calm" },
                { v: "balanced", l: "Balanced" }, { v: "snappy", l: "Snappy" }]),
            slider("animation.speed", "Speed (non-profile styles)", 0.5, 2, 0.1, "×"),
            toggle("config.animations.workspace_wraparound", "Wrap workspace switching"),
            toggle("config.misc.animate_manual_resizes", "Animate manual resizes"),
            toggle("config.misc.animate_mouse_windowdragging", "Animate window dragging")
        ]
    },
    {
        id: "input", label: "Input", icon: "\uf245",
        controls: [
            section("Mouse"),
            slider("config.input.sensitivity", "Mouse sensitivity", -1, 1, 0.05),
            choice("config.input.accel_profile", "Acceleration", [
                { v: "adaptive", l: "Adaptive", dflt: true }, { v: "flat", l: "Flat" }]),
            choice("config.input.follow_mouse", "Focus follows mouse", [
                { v: 0, l: "Off" }, { v: 1, l: "Always" }, { v: 2, l: "On click" }, { v: 3, l: "Loose" }]),
            toggle("config.input.natural_scroll", "Natural scrolling"),
            slider("config.input.scroll_factor", "Scroll speed", 0.2, 3, 0.1, "×"),
            toggle("config.input.left_handed", "Left-handed"),
            section("Touchpad"),
            toggle("config.input.touchpad.natural_scroll", "Natural scrolling"),
            toggle("config.input.touchpad.tap_to_click", "Tap to click"),
            toggle("config.input.touchpad.disable_while_typing", "Disable while typing"),
            slider("config.input.touchpad.scroll_factor", "Scroll speed", 0.2, 3, 0.1, "×"),
            section("Keyboard"),
            slider("config.input.repeat_rate", "Repeat rate", 5, 80, 1, "/s"),
            slider("config.input.repeat_delay", "Repeat delay", 100, 800, 10, " ms"),
            toggle("config.input.numlock_by_default", "Num Lock on at start")
        ]
    },
    {
        id: "cursor", label: "Cursor", icon: "\uf124",
        controls: [
            { type: "cursors" },
            slider("cursor.size", "Cursor size", 12, 48, 2, " px"),
            slider("config.cursor.inactive_timeout", "Hide when idle", 0, 15, 1, " s"),
            toggle("config.cursor.hide_on_key_press", "Hide while typing")
        ]
    },
    {
        id: "system", label: "System", icon: "\uf013",
        controls: [
            section("Startup"),
            toggle("boot.enabled", "Boot screen (next login)"),
            slider("boot.black_ms", "Boot screen delay (next login)", 0, 5000, 100, " ms"),
            section("Display"),
            choice("config.misc.vrr", "Variable refresh rate", [
                { v: 0, l: "Off" }, { v: 1, l: "On" }, { v: 2, l: "Fullscreen" }]),
            toggle("config.misc.middle_click_paste", "Middle-click paste"),
            toggle("config.misc.mouse_move_enables_dpms", "Wake on mouse move"),
            toggle("config.misc.key_press_enables_dpms", "Wake on key press"),
            section("Tweaks"),
            { type: "action" }
        ]
    }
];

var WIDE = { section: true, profile: true, themes: true, cursors: true, action: true };

function keys() {
    var out = [];
    PAGES.forEach(function (p) {
        p.controls.forEach(function (c) { if (c.key) out.push(c.key); });
    });
    return out;
}
