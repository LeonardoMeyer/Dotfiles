import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Lock screen, replacing hyprlock: the desktop blurs away into the wallpaper and the clock and password rise in;
// unlocking hands the backdrop to a layer over the desktop, drops the lock under it, and fades it into the live
// desktop. Modules toggle from the gear menu (Lock.qml keeps the settings). Runs on its own (lock.sh), not in the
// shared process, and quits once unlocked. If it crashes the session stays locked; run lock.sh again from a tty.
// lock.sh --preview shows it in windows without locking.
ShellRoot {
    id: root

    // Each monitor's last frame, taken before locking so there is something to fade from.
    property bool captured: false
    Process {
        running: true
        command: ["sh", "-c", 'mkdir -p "$0" && for o in "$@"; do grim -t ppm -o "$o" "$0/$o.ppm" & done; wait',
            Lock.shots].concat(Quickshell.screens.map(s => s.name))
        onExited: root.captured = true
    }
    // grim takes ~30ms (uncompressed ppm, quick to write and to load), but a lock must never wait on it for long.
    Timer { running: true; interval: 300; onTriggered: root.captured = true }

    WlSessionLock {
        id: lock
        locked: root.captured && !Lock.preview
        // Starts once the compositor confirms nothing else is showing; one frame first so the fade never skips.
        onSecureChanged: if (secure) startTimer.restart()

        // Transparent (with black drawn under the backdrop): an opaque surface gets a low-precision format,
        // and the blur bands.
        WlSessionLockSurface {
            color: "transparent"
            Face {
                anchors.fill: parent
                screenName: screen ? screen.name : ""
            }
        }
    }

    // The handoff: mapped (and empty) under the lock the whole time, so on unlock they are already up. They take
    // the backdrop just before the lock drops, then fade and sharpen into the live desktop.
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

            // Fading out while it eases back from pushed-in, so the desktop comes up through it.
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
