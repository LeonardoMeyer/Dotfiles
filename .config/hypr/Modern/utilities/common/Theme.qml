pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The palette and motion every utility shares (import "../common"). Same roles as waybar:
// color9 accent, color7 text, background translucent.
Singleton {
    id: root

    readonly property string sans: "CodeNewRoman Nerd Font Propo"
    readonly property int pad: 14
    readonly property int fast: 160
    // Shared motion: everything that moves into place uses the same curve.
    readonly property int move: 280
    readonly property var settle: [0.2, 0.9, 0.3, 1, 1, 1]

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
    // Destructive actions waiting for a second press.
    readonly property color warn: wal ? wal.colors.color1 : "#e06c75"
    // The visualizer's gradient, left to right.
    readonly property var spectrum: wal
        ? [wal.colors.color4, wal.colors.color9, wal.colors.color13, wal.colors.color12, wal.colors.color14]
        : ["#5f87af", "#8fd3ff", "#c3a6ff", "#87afd7", "#9fe0d0"]

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    // A color f (0-1) of the way along a list of stops.
    function along(stops, f) {
        if (!stops || stops.length === 0) return accent
        if (stops.length === 1) return stops[0]
        const x = Math.max(0, Math.min(1, f)) * (stops.length - 1)
        const i = Math.min(stops.length - 2, Math.floor(x))
        const a = Qt.color(stops[i]), b = Qt.color(stops[i + 1]), m = x - i
        return Qt.rgba(a.r + (b.r - a.r) * m, a.g + (b.g - a.g) * m, a.b + (b.b - a.b) * m, 1)
    }
}
