import QtQuick

Rectangle {
    id: sw

    property bool checked: false
    property bool hot: area.containsMouse
    signal toggled()

    width: 38
    height: 22
    radius: 11
    color: checked ? Theme.alpha(Theme.accent, 0.85) : Theme.alpha(Theme.fg, hot ? 0.24 : 0.16)
    Behavior on color { ColorAnimation { duration: Theme.ms(180) } }

    Rectangle {
        y: 3
        x: sw.checked ? parent.width - width - 3 : 3
        width: 16
        height: 16
        radius: 8
        color: sw.checked ? Theme.bg : Theme.fg
        Behavior on x { NumberAnimation { duration: Theme.ms(180); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
        Behavior on color { ColorAnimation { duration: Theme.ms(180) } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
