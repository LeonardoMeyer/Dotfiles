import QtQuick

// Pill button used for choices, profiles, themes and cursors.
Rectangle {
    id: chip

    property string text
    property bool active: false
    property var swatch: []
    property url image
    signal clicked()

    readonly property bool hot: mouse.containsMouse

    implicitHeight: 26
    implicitWidth: row.implicitWidth + 22
    radius: 8
    color: active ? Theme.alpha(Theme.accent, 0.55) : Theme.alpha(Theme.fg, hot ? 0.14 : 0.07)
    Behavior on color { ColorAnimation { duration: 220 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Image {
            visible: chip.image != ""
            width: visible ? 18 : 0
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            source: chip.image
            sourceSize.width: 36
            sourceSize.height: 36
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Row {
            visible: chip.swatch.length > 0
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: chip.swatch
                Rectangle {
                    required property string modelData
                    width: 9
                    height: 14
                    radius: 3
                    color: modelData
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.text
            font.family: Theme.sans
            font.pixelSize: 13
            color: chip.active || chip.hot ? Theme.bright : Theme.fg
            Behavior on color { ColorAnimation { duration: 220 } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
