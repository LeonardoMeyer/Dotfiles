import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Hyprland's live corner rounding: the profile's default, or the settings panel's override when one is set.
// Re-read whenever the settings panel rewrites settings.lua or the config reloads.
Scope {
    id: r

    property real value: 10

    function refresh() { proc.running = true }
    Component.onCompleted: refresh()

    Process {
        id: proc
        command: ["hyprctl", "-j", "getoption", "decoration:rounding"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const d = JSON.parse(text); if (typeof d.int === "number") r.value = d.int } catch (e) {}
            }
        }
    }

    // The file is written just before the compositor applies it, so ask a few times as it settles.
    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/settings.lua"
        watchChanges: true
        printErrors: false
        onFileChanged: { settle.n = 0; settle.restart() }
    }
    Timer {
        id: settle
        property int n: 0
        interval: 250
        repeat: true
        onTriggered: { r.refresh(); if (++n >= 3) stop() }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "configreloaded") r.refresh() }
    }
}
