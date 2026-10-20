pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Schema.js" as Schema

// Panel state. Every change updates the UI at once, then is batched to hypr-settings.py,
// which writes the active settings.lua and applies it to the running compositor.
Singleton {
    id: root

    readonly property string util: Quickshell.env("HOME") + "/.config/hypr/utilities"
    readonly property string py: util + "/hypr-settings.py"

    property var values: ({})
    property var styles: ({})
    property var active: ({ style: "", variant: "" })
    property var themes: []
    property string colorTheme: "pywal"
    property string wallpaper: ""
    property var cursors: []
    property var waybar: ({ styles: [], active: "" })
    property string waybarActive: ""
    property var caps: ({})
    property var pywalPalette: []
    property var pending: ({})
    // Wheels currently on screen; the newest one receives the panel's up/down keys.
    property var wheels: []
    property string lastSnapshot: ""
    property bool refreshAfter: false

    function refresh() {
        if (!stateProc.running) {
            stateProc.command = ["python3", py, "state"].concat(Schema.keys())
            stateProc.running = true
        }
    }

    function set(key, value) {
        if (key === "config.plugin.hyprglass.enabled" && !value)
            setMany({ [key]: value, "config.plugin.hyprglass.layers.enabled": false })
        else
            setMany({ [key]: value })
    }

    // Drops a tweak so the active profile's own value applies again.
    function reset(...keys) {
        const entries = {}
        for (const k of keys) entries[k] = null
        setMany(entries)
    }

    // Updates what the panel shows without writing anything.
    function setValues(entries) {
        values = Object.assign({}, values, entries)
    }

    // A null value removes the key; the true value is then re-read from the backend.
    function setMany(entries) {
        const glass = "config.plugin.hyprglass.enabled"
        const layers = "config.plugin.hyprglass.layers.enabled"
        // Glass off (or reset) takes bars and popups with it.
        if (entries[glass] === false || entries[glass] === null)
            entries = Object.assign({}, entries, { [layers]: entries[glass] })

        const next = Object.assign({}, values)
        for (const key of Object.keys(entries)) {
            // A removed tweak keeps its shown value until the profile's real default is read back.
            if (entries[key] !== null) next[key] = entries[key]
            pending[key] = entries[key]
            if (entries[key] === null) refreshAfter = true
        }
        values = next
        flushTimer.restart()
    }

    function flush() {
        if (setProc.running) return
        const keys = Object.keys(pending)
        if (keys.length === 0) {
            if (refreshAfter) { refreshAfter = false; lastSnapshot = ""; refresh() }
            return
        }
        const args = keys.map(k => k + "=" + JSON.stringify(pending[k]))
        pending = {}
        setProc.command = ["python3", py, "set"].concat(args)
        setProc.running = true
    }

    function applyProfile(style, variant) {
        active = { style: style, variant: variant }
        Quickshell.execDetached(["setsid", "-f", util + "/hypr-profile.sh", "apply", style, variant])
    }

    function applyTheme(id) {
        colorTheme = id
        Quickshell.execDetached(["setsid", "-f", util + "/color-apply.sh", id])
    }

    function applyWaybar(id) {
        waybarActive = id
        Quickshell.execDetached(["setsid", "-f", util + "/waybar-style.sh", "apply", id])
    }

    function resetAll() {
        if (!resetProc.running) resetProc.running = true
    }

    function saveUi(key, value) {
        Quickshell.execDetached(["python3", py, "ui", key + "=" + JSON.stringify(value)])
    }

    Timer { id: flushTimer; interval: 40; onTriggered: root.flush() }

    Process {
        id: setProc
        onExited: root.flush()
    }

    Process {
        id: resetProc
        command: ["python3", root.py, "reset"]
        onExited: root.refresh()
    }

    Process {
        id: stateProc
        stdout: StdioCollector {
            onStreamFinished: {
                let data
                try { data = JSON.parse(text) } catch (e) { return }
                // Skip identical snapshots so an unchanged refresh never re-evaluates every control.
                const snapshot = text
                if (snapshot === root.lastSnapshot) return
                root.lastSnapshot = snapshot
                // Never clobber a value the user has changed but not yet flushed.
                if (Object.keys(root.pending).length === 0 && !setProc.running) root.values = data.values
                root.styles = data.styles
                root.active = data.active
                root.themes = data.themes
                root.colorTheme = data.colorTheme
                root.wallpaper = data.wallpaper
                root.cursors = data.cursors
                root.waybar = data.waybar
                root.waybarActive = data.waybar.active
                root.caps = data.caps
                root.pywalPalette = data.pywalPalette
            }
        }
    }
}
