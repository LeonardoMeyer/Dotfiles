import QtQuick
import Quickshell

// the game as a normal window. title is "Hangman" so you can add window rules
FloatingWindow {
    id: win

    property var svc: null
    readonly property var ui: svc ? svc.ui : null

    title: "Hangman"
    visible: false
    color: "transparent"
    implicitWidth: ui ? ui.cfgSafe.windowWidth : 560
    implicitHeight: ui ? ui.cfgSafe.windowHeight : 660

    Loader {
        anchors.fill: parent
        active: win.svc !== null
        sourceComponent: Component { PanelView { svc: win.svc; shown: win.visible; focus: true } }
    }
}
