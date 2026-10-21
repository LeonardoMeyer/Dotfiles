import QtQuick
import "../common"

Item {
    id: control

    property var def
    readonly property var raw: Store.values[def.key]
    readonly property bool ready: raw !== undefined && raw !== null
    readonly property bool on: ready && !!raw
    readonly property bool hot: area.containsMouse

    implicitHeight: 46
    opacity: ready ? 1 : 0.35

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Theme.pad
        anchors.right: knobTrack.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: control.def.label
        elide: Text.ElideRight
        font.family: Theme.sans
        font.pixelSize: 13
        color: control.hot ? Theme.bright : Theme.fg
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }

    Rectangle {
        id: knobTrack
        anchors.right: parent.right
        anchors.rightMargin: Theme.pad
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 22
        radius: 11
        color: control.on ? Theme.alpha(Theme.accent, 0.85) : Theme.alpha(Theme.fg, 0.16)
        Behavior on color { ColorAnimation { duration: 180 } }

        Rectangle {
            y: 3
            x: control.on ? parent.width - width - 3 : 3
            width: 16
            height: 16
            radius: 8
            color: control.on ? Theme.bg : Theme.fg
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 180 } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: control.ready
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const changes = {}
            changes[control.def.key] = !control.on
            const r = control.def.raises
            // Some options need another one to be visible at all (a gradient border needs a border).
            if (!control.on && r && Store.values[r.key] < r.min) changes[r.key] = r.min
            Store.setMany(changes)
        }
    }

    // Right-click puts the setting back to the profile's own value.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: Store.reset(control.def.key)
    }
}
