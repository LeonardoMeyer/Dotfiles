pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris

// shared palette, animation timing and helpers
Singleton {
    id: root

    readonly property string sans: "CodeNewRoman Nerd Font Propo"
    readonly property int pad: 14

    property real rounding: 10
    property bool glass: false
    property bool hyprAnimates: true
    property real hyprPace: 1
    property var hyprSettle: own
    property var hyprLeave: own
    readonly property bool ownMotion: /\["utilities"\]\s*=\s*\{[^}]*\["animations"\]\s*=\s*true/.test(settingsFile.text())

    readonly property var own: [0.2, 0.9, 0.3, 1, 1, 1]
    readonly property bool animates: ownMotion || hyprAnimates
    readonly property real pace: ownMotion ? 1 : hyprPace
    readonly property var settle: ownMotion ? own : hyprSettle
    readonly property var leave: ownMotion ? own : hyprLeave
    readonly property int fast: ms(160)
    readonly property int move: ms(280)

    // corner radius scaled to hyprland's rounding
    function r(px) {
        return px * rounding / 10
    }

    function ms(d) {
        return animates ? Math.round(d * pace) : 0
    }

    function refresh() {
        optionProc.running = true
        curveProc.running = true
        glassProc.running = true
    }
    Component.onCompleted: refresh()

    Process {
        id: optionProc
        command: ["sh", "-c", "hyprctl -j getoption decoration:rounding; hyprctl -j getoption animations:enabled"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const [r, a] = text.trim().split(/\n(?=\{)/).map(s => JSON.parse(s))
                    if (typeof r.int === "number") root.rounding = r.int
                    root.hyprAnimates = a.bool ?? a.int !== 0
                } catch (e) {}
            }
        }
    }

    // hyprctl errors instead of JSON without the plugin
    Process {
        id: glassProc
        command: ["sh", "-c", "for o in enabled namespaces exclude_namespaces; do hyprctl -j getoption plugin:hyprglass:layers:$o; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const [on, only, except] = text.trim().split(/\n(?=\{)/).map(s => JSON.parse(s))
                    const ns = "quickshell-bar"
                    const has = o => (o.str || "").split(",").includes(ns)
                    root.glass = on.int === 1 && (!only.str || only.str === "[[EMPTY]]" || has(only)) && !has(except)
                } catch (e) { root.glass = false }
            }
        }
    }

    Process {
        id: curveProc
        command: ["hyprctl", "-j", "animations"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const [leaves, beziers] = JSON.parse(text)
                    const parent = { windowsIn: "windows", windowsOut: "windows", windows: "global" }
                    const leaf = (name, has) => {
                        for (let n = name; n; n = parent[n]) {
                            const l = leaves.find(a => a.name === n)
                            if (l && has(l)) return l
                        }
                        return null
                    }
                    const curve = name => {
                        const l = leaf(name, l => !!l.bezier && beziers.some(b => b.name === l.bezier))
                        const b = l ? beziers.find(b => b.name === l.bezier) : null
                        return b ? [b.X0, b.Y0, b.X1, b.Y1, 1, 1] : null
                    }
                    root.hyprSettle = curve("windowsIn") ?? root.own
                    root.hyprLeave = curve("windowsOut") ?? root.hyprSettle
                    // speed is in deciseconds, 3 is what everything was tuned at
                    const w = leaf("windowsIn", l => l.speed > 0)
                    root.hyprPace = w ? Math.max(0.2, Math.min(3, w.speed / 3)) : 1
                } catch (e) {}
            }
        }
    }

    // file is written right before hyprland applies it, so retry a few times
    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/hypr/settings.lua"
        watchChanges: true
        printErrors: false
        onFileChanged: { reload(); settleTimer.n = 0; settleTimer.restart() }
    }
    Timer {
        id: settleTimer
        property int n: 0
        interval: 250
        repeat: true
        onTriggered: { root.refresh(); if (++n >= 3) stop() }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "configreloaded") root.refresh() }
    }

    // lua dispatch if hyprland.lua is in use
    FileView {
        id: luaFile
        path: Quickshell.env("HOME") + "/.config/hypr/hyprland.lua"
        blockLoading: true
        printErrors: false
    }
    readonly property bool lua: luaFile.text() !== ""

    function dispatch(lua, classic) {
        Hyprland.dispatch(root.lua ? lua : classic)
    }

    // skip playerctld, it keeps the last track after players stop
    readonly property var players: Mpris.players.values.filter(p => !(p.dbusName || "").includes("playerctld"))

    function isSpotify(x) {
        return !!x && [x.identity, x.dbusName, x.id, x.title, x.tooltipTitle].some(s => (s || "").toLowerCase().includes("spotify"))
    }

    function openSpotify() {
        Quickshell.execDetached([Quickshell.shellDir + "/common/spotify.sh"])
    }

    // focusedMonitor can be stale at startup, so ask for the cursor position
    function locate(done) {
        located.push(done)
        cursorQuery.running = true
    }
    function screenAt(x, y) {
        return Quickshell.screens.find(s => x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height)
            ?? Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
            ?? Quickshell.screens[0]
    }
    property var located: []
    function found(c) {
        const scr = c ? screenAt(c.x, c.y) : screenAt(-1, -1)
        const done = located
        located = []
        done.forEach(f => f(scr))
    }
    Process {
        id: cursorQuery
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                let c = null
                try { c = JSON.parse(text) } catch (e) {}
                root.found(c)
            }
        }
        onExited: code => { if (code !== 0) root.found(null) }
    }

    FileView {
        id: walFile
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
    }

    readonly property var saved: {
        try { return JSON.parse(walFile.text()) } catch (e) { return null }
    }
    // wallpaper picker preview palette, null when not previewing
    property var preview: null
    readonly property var wal: preview ? {
        colors: preview.reduce((o, c, i) => (o["color" + i] = c, o), {}),
        special: { background: preview[0], foreground: preview[15] }
    } : saved
    readonly property color accent: wal ? wal.colors.color9 : "#8fd3ff"
    readonly property color fg: wal ? wal.colors.color7 : "#c7c6c2"
    readonly property color bright: wal ? wal.colors.color15 : "#ffffff"
    // based on the text color, color8 is too dark on some schemes
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.5)
    readonly property color bg: wal ? wal.special.background : "#101418"
    readonly property color warn: wal ? wal.colors.color1 : "#e06c75"
    readonly property var spectrum: wal
        ? [wal.colors.color4, wal.colors.color9, wal.colors.color13, wal.colors.color12, wal.colors.color14]
        : ["#5f87af", "#8fd3ff", "#c3a6ff", "#87afd7", "#9fe0d0"]

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function along(stops, f) {
        if (!stops || stops.length === 0) return accent
        if (stops.length === 1) return stops[0]
        const x = Math.max(0, Math.min(1, f)) * (stops.length - 1)
        const i = Math.min(stops.length - 2, Math.floor(x))
        const a = Qt.color(stops[i]), b = Qt.color(stops[i + 1]), m = x - i
        return Qt.rgba(a.r + (b.r - a.r) * m, a.g + (b.g - a.g) * m, a.b + (b.b - a.b) * m, 1)
    }
}
