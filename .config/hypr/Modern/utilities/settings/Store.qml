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
    property var pending: ({})

    function refresh() {
        if (!stateProc.running) {
            stateProc.command = ["python3", py, "state"].concat(Schema.keys())
            stateProc.running = true
        }
    }

    function set(key, value) {
        const next = Object.assign({}, values)
        next[key] = value
        values = next
        pending[key] = value
        flushTimer.restart()
    }

    function flush() {
        if (setProc.running) return
        const keys = Object.keys(pending)
        if (keys.length === 0) return
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

    function resetAll() {
        if (!resetProc.running) resetProc.running = true
    }

    function saveUi(key, value) {
        Quickshell.execDetached(["python3", py, "ui", key + "=" + JSON.stringify(value)])
    }

    Timer { id: flushTimer; interval: 120; onTriggered: root.flush() }

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
                // Never clobber a value the user has changed but not yet flushed.
                if (Object.keys(root.pending).length === 0 && !setProc.running) root.values = data.values
                root.styles = data.styles
                root.active = data.active
                root.themes = data.themes
                root.colorTheme = data.colorTheme
                root.wallpaper = data.wallpaper
                root.cursors = data.cursors
            }
        }
    }
}
