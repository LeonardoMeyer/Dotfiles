import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    id: root

    readonly property string sans: "CodeNewRoman Nerd Font Propo"
    readonly property string home: Quickshell.env("HOME")

    // Resident and hidden; present() drives every appearance.
    property bool active: false
    property bool leaving: false
    property real t: 0
    property real pulse: 0

    property string kind: "volume"
    property bool flag: false
    property string label: ""
    property real shownValue: 0

    FileView {
        id: walFile
        path: root.home + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property var wal: {
        try { return JSON.parse(walFile.text()) } catch (e) { return null }
    }
    // Same palette roles as waybar: color9 accent, color7 text, background at 0.6.
    readonly property color accent: wal ? wal.colors.color9 : "#8fd3ff"
    readonly property color fg: wal ? wal.colors.color7 : "#c7c6c2"
    readonly property color bright: wal ? wal.colors.color15 : "#ffffff"
    readonly property color dim: wal ? wal.colors.color8 : "#716e5d"
    readonly property color bg: wal ? wal.special.background : "#101418"

    readonly property bool hasBar: kind === "volume" || kind === "brightness"
    readonly property bool off: kind === "volume" ? flag : false
    readonly property string glyph: {
        switch (kind) {
        case "volume": return flag || shownValue < 0.005 ? "\uf026" : (shownValue < 0.45 ? "\uf027" : "\uf028")
        case "brightness": return "\uf185"
        case "mic": return flag ? "\uf131" : "\uf130"
        case "caps": return flag ? "\uf023" : "\uf09c"
        case "play": return "\uf04b"
        case "pause": return "\uf04c"
        case "next": return "\uf051"
        case "prev": return "\uf048"
        }
        return ""
    }
    readonly property string title: {
        switch (kind) {
        case "caps": return "Caps Lock"
        case "mic": return "Microphone"
        case "play": case "pause": case "next": case "prev": return label !== "" ? label : (kind === "pause" ? "Paused" : "Playing")
        }
        return ""
    }
    readonly property string readout: {
        if (hasBar) return flag ? "MUTE" : Math.round(shownValue * 100) + "%"
        if (kind === "caps") return flag ? "ON" : "OFF"
        if (kind === "mic") return flag ? "OFF" : "ON"
        return ""
    }
    readonly property bool readoutLit: kind === "caps" ? flag : (kind === "mic" ? !flag : !off)

    function present(k, v, f, text) {
        const fresh = !active || leaving || kind !== k
        kind = k
        flag = f
        label = text
        if (fresh) {
            barBehavior.enabled = false
            shownValue = v
            barBehavior.enabled = true
        } else {
            shownValue = v
        }

        hideTimer.restart()
        if (!active) {
            active = true
            leaving = false
            t = 0
            animateTo(1)
        } else if (leaving) {
            leaving = false
            animateTo(1)
        } else {
            pulseAnim.restart()
        }
    }

    // Same curves and timings as style.lua: windows use "fluid" at 300ms, windowsOut "snappy" at 250ms, popin 5%.
    function animateTo(target) {
        tween.stop()
        tween.from = t
        tween.to = target
        tween.duration = target === 1 ? 300 : 250
        tween.easing.type = Easing.BezierSpline
        tween.easing.bezierCurve = target === 1 ? [0.15, 0.85, 0.25, 1, 1, 1] : [0.3, 1, 0.4, 1, 1, 1]
        tween.start()
    }

    function hide() {
        if (!active || leaving) return
        leaving = true
        animateTo(0)
    }

    NumberAnimation {
        id: tween
        target: root
        property: "t"
        onFinished: if (root.leaving) { root.active = false; root.leaving = false; root.t = 0 }
    }

    Timer { id: hideTimer; interval: 1400; onTriggered: root.hide() }

    SequentialAnimation {
        id: pulseAnim
        NumberAnimation { target: root; property: "pulse"; to: 1; duration: 70; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "pulse"; to: 0; duration: 180; easing.type: Easing.OutCubic }
    }

    IpcHandler {
        target: "osd"
        function notify(kind: string, value: real, flag: bool, text: string): void { root.present(kind, value, flag, text) }
    }

    PanelWindow {
        id: win
        visible: root.active
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors.bottom: true
        margins.bottom: 56
        implicitWidth: 340
        implicitHeight: 100
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Item {
            id: card
            width: 300
            height: 52
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            opacity: root.t
            scale: 0.95 + 0.05 * root.t

            // Matches Hyprland: 10px rounding, no border, translucent background over compositor blur.
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.45)
            }

            Text {
                id: icon
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                horizontalAlignment: Text.AlignHCenter
                text: root.glyph
                font.family: root.sans
                font.pixelSize: 18
                color: root.off ? root.dim : root.accent
                scale: 1 + 0.18 * root.pulse
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Text {
                id: readout
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: root.readout
                font.family: root.sans
                font.pixelSize: 14
                color: root.readoutLit ? root.fg : root.dim
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Rectangle {
                id: meter
                visible: root.hasBar
                anchors.left: icon.right
                anchors.leftMargin: 14
                anchors.right: readout.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.16)

                Rectangle {
                    height: parent.height
                    radius: 2
                    width: parent.width * Math.max(0, Math.min(1, root.shownValue))
                    color: root.off ? root.dim : root.accent
                    Behavior on color { ColorAnimation { duration: 90 } }
                }
            }

            Text {
                visible: !root.hasBar
                anchors.left: icon.right
                anchors.leftMargin: 14
                anchors.right: readout.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                elide: Text.ElideRight
                font.family: root.sans
                font.pixelSize: 15
                color: root.fg
            }
        }
    }

    Behavior on shownValue { id: barBehavior; NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
}
