import QtQuick

// One category in the left rail.
Rectangle {
    id: item

    property string icon
    property string text
    property bool active: false
    signal clicked()

    readonly property bool hot: mouse.containsMouse

    implicitHeight: 30
    radius: 8
    color: active ? Theme.alpha(Theme.fg, 0.1) : (hot ? Theme.alpha(Theme.fg, 0.05) : "transparent")
    Behavior on color { ColorAnimation { duration: 220 } }

    Rectangle {
        width: 3
        height: item.active ? 14 : 0
        radius: 2
        anchors.left: parent.left
        anchors.leftMargin: 3
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.accent
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    Text {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        horizontalAlignment: Text.AlignHCenter
        text: item.icon
        font.family: Theme.sans
        font.pixelSize: 14
        color: item.active || item.hot ? Theme.bright : Theme.fg
        Behavior on color { ColorAnimation { duration: 220 } }
    }

    Text {
        anchors.left: glyph.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: item.text
        elide: Text.ElideRight
        font.family: Theme.sans
        font.pixelSize: 14
        color: item.active || item.hot ? Theme.bright : Theme.fg
        Behavior on color { ColorAnimation { duration: 220 } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: item.clicked()
    }
}
