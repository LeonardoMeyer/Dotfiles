import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // last frame of each monitor, to fade from
    property bool captured: false
    Process {
        running: true
        command: ["sh", "-c", 'mkdir -p "$0" && for o in "$@"; do grim -t ppm -o "$o" "$0/$o.ppm" & done; wait',
            Lock.shots].concat(Quickshell.screens.map(s => s.name))
        onExited: root.captured = true
    }
    // don't wait on grim for long
    Timer { running: true; interval: 300; onTriggered: root.captured = true }

    WlSessionLock {
        id: lock
        locked: root.captured && !Lock.preview
        onSecureChanged: if (secure) startTimer.restart()

        // transparent, opaque surfaces get a low precision format and the blur bands
        WlSessionLockSurface {
            color: "transparent"
            Face {
                anchors.fill: parent
                screenName: screen ? screen.name : ""
            }
        }
    }

    // handoff layers sit under the lock so unlocking is seamless
    Variants {
        model: !Lock.preview && root.captured ? Quickshell.screens : []
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "lock-handoff"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            Backdrop {
                anchors.fill: parent
                visible: Lock.handoff
                amount: Lock.fade
                opacity: Lock.fade
            }
        }
    }

    Variants {
        model: Lock.preview && root.captured ? Quickshell.screens : []
        FloatingWindow {
            required property var modelData
            title: "Lock preview"
            implicitWidth: Math.round(modelData.width * 0.7)
            implicitHeight: Math.round(modelData.height * 0.7)
            color: "transparent"
            Face {
                anchors.fill: parent
                screenName: modelData.name
            }
            Component.onCompleted: startTimer.restart()
        }
    }

    Timer { id: startTimer; interval: 40; onTriggered: Lock.enter() }

    Connections {
        target: Lock
        function onUnlock() { lock.locked = false }
        function onFinish() { Qt.quit() }
    }
}
