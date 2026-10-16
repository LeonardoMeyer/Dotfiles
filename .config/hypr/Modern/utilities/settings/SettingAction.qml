import QtQuick

// Drops every tweak and returns to the active profile's own values; needs a second click to confirm.
Item {
    id: control

    property var def
    property bool armed: false

    implicitHeight: 52

    Timer { id: disarm; interval: 2500; onTriggered: control.armed = false }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 9
        radius: 8
        color: control.armed ? Theme.alpha("#e5566d", 0.45) : Theme.alpha(Theme.fg, area.containsMouse ? 0.14 : 0.07)
        Behavior on color { ColorAnimation { duration: Theme.fast } }

        Text {
            anchors.centerIn: parent
            text: control.armed ? "Click again to reset everything" : "Reset tweaks to profile defaults"
            font.family: Theme.sans
            font.pixelSize: 12
            color: control.armed || area.containsMouse ? Theme.bright : Theme.fg
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (control.armed) {
                    control.armed = false
                    Store.resetAll()
                } else {
                    control.armed = true
                    disarm.restart()
                }
            }
        }
    }
}
