import QtQuick

Item {
    id: control

    property var def

    implicitHeight: 24

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        text: control.def.label.toUpperCase()
        font.family: Theme.sans
        font.pixelSize: 11
        font.letterSpacing: 1.5
        color: Theme.dim
    }
}
