pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

// shared lock state. can't import ../common, so enjoy the copy-paste, you absolute bastard
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string user: Quickshell.env("USER")
    readonly property string sans: "CodeNewRoman Nerd Font Propo"
    readonly property bool preview: Quickshell.env("LOCK_PREVIEW") === "1"
    readonly property string shots: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-lock"


    FileView {
        id: walFile
        path: root.home + "/.cache/wal/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    readonly property var wal: {
        try { return JSON.parse(walFile.text()) } catch (e) { return null }
    }
    readonly property color accent: wal ? wal.colors.color9 : "#8fd3ff"
    readonly property color fg: wal ? wal.colors.color7 : "#c7c6c2"
    readonly property color bg: wal ? wal.special.background : "#101418"
    readonly property color warn: wal ? wal.colors.color1 : "#e06c75"
    readonly property color card: alpha(bg, 0.5)
    readonly property color popup: alpha(bg, 0.86)
    readonly property color edge: alpha(fg, 0.07)
    readonly property string wallpaper: {
        const p = walPath.text().trim()
        return p ? "file://" + encodeURI(p) : ""
    }
    FileView { id: walPath; path: root.home + "/.cache/wal/wal"; printErrors: false }

    readonly property var spectrum: wal
        ? [wal.colors.color4, wal.colors.color9, wal.colors.color13, wal.colors.color12, wal.colors.color14]
        : ["#5f87af", "#8fd3ff", "#c3a6ff", "#87afd7", "#9fe0d0"]

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function along(stops, f) {
        if (!stops || stops.length === 0) return accent
        if (stops.length === 1) return stops[0]
        const x = Math.max(0, Math.min(1, f)) * (stops.length - 1)
        const i = Math.min(stops.length - 2, Math.floor(x))
        const a = Qt.color(stops[i]), b = Qt.color(stops[i + 1]), m = x - i
        return Qt.rgba(a.r + (b.r - a.r) * m, a.g + (b.g - a.g) * m, a.b + (b.b - a.b) * m, 1)
    }
    function corner(h, u) { return Math.min(h / 2, rounding * u) }


    property real rounding: 10
    readonly property var settle: [0.2, 0.9, 0.3, 1, 1, 1]
    Process {
        running: true
        command: ["hyprctl", "-j", "getoption", "decoration:rounding"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.rounding = JSON.parse(text).int } catch (e) {} }
        }
    }

    property real t: 0
    function seg(delay) { return Math.max(0, Math.min(1, (t - delay) / (1 - delay))) }
    NumberAnimation { id: tween; target: root; property: "t"; to: 1; duration: 750; easing.type: Easing.OutCubic }
    function enter() { if (!leaving && !tween.running && t < 1) tween.start() }

    property bool leaving: false
    property real out: 0
    property bool handoff: false
    property real fade: 1
    signal unlock()
    signal finish()
    function leave() {
        if (leaving) return
        leaving = true
        tween.stop()
        outro.start()
    }
    SequentialAnimation {
        id: outro
        NumberAnimation { target: root; property: "out"; to: 1; duration: 200; easing.type: Easing.InQuad }
        ScriptAction { script: root.handoff = true }
        PauseAnimation { duration: 34 }
        ScriptAction { script: root.unlock() }
        PauseAnimation { duration: 16 }
        NumberAnimation { target: root; property: "fade"; to: 0; duration: 600; easing.type: Easing.OutCubic }
        ScriptAction { script: root.finish() }
    }


    readonly property var defaults: ({ clock: true, greeter: true, music: true, battery: true, power: true, idleHide: true })
    readonly property var labels: [
        ["clock", "Clock"], ["greeter", "Greeter"], ["music", "Music"], ["battery", "Battery"],
        ["power", "Power buttons"], ["idleHide", "Fade on idle"]
    ]
    readonly property string statePath: home + "/.local/state/quickshell-lock.json"
    FileView { id: stateFile; path: root.statePath; printErrors: false; blockLoading: true }
    property var cfg: {
        let saved = {}
        try { saved = JSON.parse(stateFile.text()) } catch (e) {}
        return Object.assign({}, defaults, saved)
    }
    function set(key, value) {
        const c = Object.assign({}, cfg)
        c[key] = value
        cfg = c
        Quickshell.execDetached(["mkdir", "-p", home + "/.local/state"])
        stateFile.setText(JSON.stringify(c, null, 2))
    }
    property bool menuOpen: false


    property string password: ""
    property bool failed: false
    property bool checking: false
    signal rejected()

    function submit() {
        if (checking || password === "") return
        checking = true
        failed = false
        pam.start()
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellPath("pam")
        config: "password.conf"
        user: root.user
        onPamMessage: if (responseRequired) respond(root.password)
        onCompleted: result => {
            root.checking = false
            if (result === PamResult.Success) {
                root.menuOpen = false
                root.leave()
            } else {
                root.password = ""
                root.failed = true
                root.rejected()
            }
        }
        onError: { root.checking = false; root.password = ""; root.failed = true; root.rejected() }
    }

    property bool capsLock: false
    Process {
        id: capsProc
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.capsLock = JSON.parse(text).keyboards.some(k => k.main && k.capsLock) } catch (e) {}
            }
        }
    }
    function checkCaps() { if (!capsProc.running) capsProc.running = true }


    property bool idle: false
    function poke() {
        idle = false
        idleTimer.restart()
    }
    Timer {
        id: idleTimer
        interval: 12000
        running: true
        onTriggered: root.idle = root.cfg.idleHide && root.password === "" && !root.menuOpen
    }


    // spotify first, then whatever's playing
    readonly property var player: {
        const ps = Mpris.players.values.filter(p => !(p.dbusName || "").includes("playerctld"))
        if (ps.length === 0) return null
        const spotify = p => [p.identity, p.dbusName].some(s => (s || "").toLowerCase().includes("spotify"))
        return ps.find(spotify) ?? ps.find(p => p.isPlaying) ?? ps[0]
    }
    Timer {
        interval: 1000
        repeat: true
        running: !!root.player && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: !!battery && battery.isLaptopBattery && battery.isPresent
    readonly property real charge: hasBattery ? (battery.percentage > 1 ? battery.percentage / 100 : battery.percentage) : 0
    readonly property bool charging: hasBattery
        && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged)

    readonly property string mainScreen: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    property string lockedOn: ""
    onMainScreenChanged: if (lockedOn === "") lockedOn = mainScreen
    Component.onCompleted: { lockedOn = mainScreen; checkCaps() }
}
