import QtQuick

// Drops every tweak and returns to the active profile's own values; needs a second click to confirm.
Item {
    id: control

    property var def
    property bool armed: false

    implicitHeight: 28

    Timer { id: disarm; interval: 2500; onTriggered: control.armed = false }

    Chip {
        text: control.armed ? "Click again to reset everything" : "Reset tweaks to profile defaults"
        active: control.armed
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
