import QtQuick

Item {
    id: control

    property var def
    readonly property var raw: Store.values[def.key]
    readonly property bool ready: raw !== undefined && raw !== null
    readonly property bool on: ready && raw === true
    readonly property bool hot: area.containsMouse

    implicitHeight: 46
    opacity: ready ? 1 : 0.35

    Text {
        anchors.left: parent.left
        anchors.right: knobTrack.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: control.def.label
        elide: Text.ElideRight
        font.family: Theme.sans
        font.pixelSize: 13
        color: control.hot ? Theme.bright : Theme.fg
        Behavior on color { ColorAnimation { duration: 220 } }
    }

    Rectangle {
        id: knobTrack
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 20
        radius: 10
        color: control.on ? Theme.alpha(Theme.accent, 0.85) : Theme.alpha(Theme.fg, 0.16)
        Behavior on color { ColorAnimation { duration: 180 } }

        Rectangle {
            y: 3
            x: control.on ? parent.width - width - 3 : 3
            width: 14
            height: 14
            radius: 7
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
        onClicked: Store.set(control.def.key, !control.on)
    }
}
