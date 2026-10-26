import QtQuick

Item {
    id: row

    property string label
    property bool checked
    property real u: 1
    signal toggled()

    width: parent ? parent.width : 240
    height: 34 * u

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2 * row.u
        radius: Lock.corner(height, row.u)
        color: Lock.alpha(Lock.fg, area.containsMouse ? 0.06 : 0)
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 8 * row.u
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        font.family: Lock.sans
        font.pixelSize: 13 * row.u
        color: row.checked ? "#ffffff" : "#b3ffffff"
        Behavior on color { ColorAnimation { duration: 180 } }
    }

    Rectangle {
        id: sw
        anchors.right: parent.right
        anchors.rightMargin: 8 * row.u
        anchors.verticalCenter: parent.verticalCenter
        width: 38 * row.u
        height: 22 * row.u
        radius: height / 2
        color: row.checked ? Lock.alpha(Lock.accent, 0.85) : Lock.alpha(Lock.fg, area.containsMouse ? 0.24 : 0.16)
        Behavior on color { ColorAnimation { duration: 180 } }

        Rectangle {
            y: 3 * row.u
            x: row.checked ? parent.width - width - 3 * row.u : 3 * row.u
            width: 16 * row.u
            height: 16 * row.u
            radius: width / 2
            color: row.checked ? Lock.bg : Lock.fg
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.BezierSpline; easing.bezierCurve: Lock.settle } }
            Behavior on color { ColorAnimation { duration: 180 } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.toggled()
    }
}
