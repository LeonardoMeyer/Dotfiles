import QtQuick

// A square button on a card, its corners following Hyprland's rounding like the home screen's dock. `filled` is the
// accent with a dark glyph; `armed` turns it the warning color.
Item {
    id: b

    property string glyph
    property real u: 1
    property real size: 44 * u
    property color tint: "#ffffff"
    property bool filled: false
    property bool armed: false
    signal clicked()

    width: size
    height: size
    scale: area.pressed ? 0.9 : area.containsMouse ? 1.06 : 1
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: Lock.settle } }

    Card {
        anchors.fill: parent
        radius: Lock.corner(b.size, b.u)
        opacity: b.filled || b.armed ? 0 : 1
    }
    Rectangle {
        anchors.fill: parent
        radius: Lock.corner(b.size, b.u)
        color: b.armed ? Lock.warn : Lock.accent
        opacity: b.filled || b.armed ? (area.containsMouse ? 1 : 0.88) : area.containsMouse ? 0.12 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    Text {
        anchors.centerIn: parent
        text: b.glyph
        font.family: Lock.sans
        font.pixelSize: b.size * 0.4
        color: b.filled || b.armed ? Lock.bg : b.tint
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
