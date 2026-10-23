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
    // waybar or quickshell, and the quickshell bar's styles.
    property string bar: "waybar"
    property var quickshell: ({ styles: [], active: "" })
    property string quickshellActive: ""
    property var caps: ({})
    property var pywalPalette: []
    // The profile page's list: Default, each variant's tweaks, saved snapshots; and which one is live.
    property var saved: ({ entries: [], active: "default" })
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
        entries = Schema.glassTargets(entries, values)
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

    // Colors, the bar and waybar are part of the applied profile entry too, recorded like any other edit.
    function applyTheme(id) {
        colorTheme = id
        Quickshell.execDetached(["setsid", "-f", util + "/color-apply.sh", id])
        setMany({ "colors.theme": id })
    }

    function applyWaybar(id) {
        waybarActive = id
        Quickshell.execDetached(["env", "HYPR_SETTINGS_NO_RECORD=1", "setsid", "-f", util + "/waybar-style.sh", "apply", id])
        setMany({ "waybar.style": id })
    }

    function applyQuickshell(id) {
        quickshellActive = id
        Quickshell.execDetached(["env", "HYPR_SETTINGS_NO_RECORD=1", "setsid", "-f", util + "/bar.sh", "style", id])
        setMany({ "quickshell.style": id })
    }

    function applyBar(id) {
        bar = id
        Quickshell.execDetached(["env", "HYPR_SETTINGS_NO_RECORD=1", "setsid", "-f", util + "/bar.sh", "apply", id])
        // bar.sh puts waybar back to its default style while the quickshell bar is up.
        if (id === "quickshell") {
            waybarActive = "default"
            setMany({ "bar.kind": id, "waybar.style": "default" })
        } else setMany({ "bar.kind": id })
    }

    // action: save NAME | apply ID | delete ID | wipe. Runs one at a time; the panel re-reads everything afterwards.
    function savedRun(action, name) {
        if (savedProc.running) return
        savedProc.command = ["python3", py, "saved", action].concat(name ? [name] : [])
        savedProc.running = true
    }

    function saveUi(key, value) {
        Quickshell.execDetached(["python3", py, "ui", key + "=" + JSON.stringify(value)])
    }

    Timer { id: flushTimer; interval: 40; onTriggered: root.flush() }

    Process {
        id: setProc
        onExited: {
            // An edit on Default makes the active variant's tweaks live; re-read the list once so it shows.
            if (root.saved.active === "default") root.refreshAfter = true
            root.flush()
        }
    }

    Process {
        id: savedProc
        onExited: { root.lastSnapshot = ""; root.refresh() }
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
                root.bar = data.bar || "waybar"
                root.quickshell = data.quickshell || { styles: [], active: "" }
                root.quickshellActive = root.quickshell.active
                root.caps = data.caps
                root.pywalPalette = data.pywalPalette
                root.saved = data.saved || { entries: [], active: "default" }
            }
        }
    }
}
