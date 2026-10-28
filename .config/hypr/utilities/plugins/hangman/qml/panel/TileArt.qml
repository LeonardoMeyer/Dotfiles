import QtQuick

// the little picture on a settings tile
Item {
    id: root

    property var ui: null
    property string key: ""
    property string opt: ""
    property bool on: false

    width: 64
    height: 44

    readonly property color ink: on ? ui.accent : ui.tint(0.55)
    readonly property color soft: on ? ui.accentTint(0.40) : ui.tint(0.20)

    // drawing: the real thing, half way through a word
    Figure {
        visible: root.key === "figure"
        anchors.fill: parent
        ui: root.ui
        style: root.opt
        lives: 6
        wrong: 3
        animate: false
        opacity: root.on ? 1 : 0.7
    }

    // spacing
    Row {
        visible: root.key === "density"
        anchors.centerIn: parent
        spacing: root.opt === "compact" ? 2 : (root.opt === "spacious" ? 9 : 5)
        Repeater { model: 4; Rectangle { width: 9; height: 2; radius: 1; y: 16; color: root.ink } }
    }

    // open as
    Item {
        visible: root.key === "openAs"
        anchors.fill: parent
        Rectangle { x: 6; y: 6; width: 52; height: 5; radius: 2; color: root.soft }
        Rectangle {
            x: root.opt === "panel" ? 12 : 18
            y: root.opt === "panel" ? 12 : 16
            width: 28; height: 22; radius: 3
            color: root.ink
        }
    }
}
