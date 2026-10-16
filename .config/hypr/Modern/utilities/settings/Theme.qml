pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Same palette roles as waybar, the OSD and the boot screen: color9 accent, color7 text, background translucent.
Singleton {
    id: root

    readonly property string sans: "CodeNewRoman Nerd Font Propo"
    readonly property int pad: 14
    readonly property int fast: 160

    FileView {
        id: walFile
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
    }

    readonly property var wal: {
        try { return JSON.parse(walFile.text()) } catch (e) { return null }
    }
    readonly property color accent: wal ? wal.colors.color9 : "#8fd3ff"
    readonly property color fg: wal ? wal.colors.color7 : "#c7c6c2"
    readonly property color bright: wal ? wal.colors.color15 : "#ffffff"
    // Derived from the text color so it stays readable on every palette (color8 is too dark on schemes like Nord).
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.5)
    readonly property color bg: wal ? wal.special.background : "#101418"

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
}
