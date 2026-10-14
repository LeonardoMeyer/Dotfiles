import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Floating pop-ups for new notifications, bottom left of the focused monitor; hidden while the home screen is open.
PanelWindow {
    id: win

    required property var shell
    readonly property var focusScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    // Sized from the shorter screen side so cards stay the same width on portrait and landscape monitors.
    readonly property real u: focusScreen ? Math.max(0.6, Math.min(1.6, Math.min(focusScreen.width, focusScreen.height) / 900)) : 1
    readonly property int wanted: shell.popups.length
    // Stays mapped briefly after the last card so its exit animation finishes.
    property bool alive: false

    // The list only builds its cards once the window is mapped, so mapping follows the data rather than list.count.
    onWantedChanged: {
        if (wanted > 0) {
            linger.stop()
            alive = true
        } else linger.restart()
    }

    screen: focusScreen
    visible: !shell.shown && alive
    anchors { top: true; left: true; bottom: true }
    // Extra width leaves room for the card shadows, which would otherwise be clipped at the surface edge.
    implicitWidth: 440 * u
    color: "transparent"
    // Auto would reserve this strip's width as an exclusive zone and push tiled windows aside.
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notification-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Only the cards take clicks; the rest of the strip passes input through.
    mask: Region { item: list }

    Timer { id: linger; interval: 600; onTriggered: win.alive = false }

    ListView {
        id: list
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16 * win.u
        anchors.left: parent.left
        anchors.leftMargin: 16 * win.u
        width: 380 * win.u
        height: contentHeight
        interactive: false
        spacing: 10 * win.u
        // Newest last, so it lands at the bottom and older cards stack above it.
        model: ScriptModel { values: win.shell.popups.slice().reverse() }

        delegate: Item {
            id: slot
            required property var modelData
            // expireTimeout is in milliseconds; -1 means the sender has no preference, 0 means never expire.
            readonly property real secs: modelData.expireTimeout > 0 ? modelData.expireTimeout / 1000 : 6
            readonly property bool sticky: modelData.expireTimeout === 0
                || (modelData.urgency === NotificationUrgency.Critical && modelData.expireTimeout < 0)
            property real remain: 1

            width: list.width
            height: card.height

            NotificationCard {
                id: card
                width: parent.width
                n: slot.modelData
                shell: win.shell
                u: win.u
                popup: true
                progress: slot.sticky ? -1 : slot.remain
                scale: hovered ? 1.015 : 1
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            // Counts down the card's bar and dismisses it at zero; hovering freezes both.
            NumberAnimation {
                target: slot
                property: "remain"
                from: 1
                to: 0
                duration: slot.secs * 1000
                running: !slot.sticky
                paused: card.hovered
                onFinished: win.shell.expirePopup(slot.modelData)
            }
        }

        // Cards ease in from the left with a small overshoot, so they read as part of the shell rather than a stuck-on window.
        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: -90 * win.u; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
                NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 420; easing.type: Easing.OutCubic }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 220; easing.type: Easing.InCubic }
                NumberAnimation { property: "x"; to: -80 * win.u; duration: 280; easing.type: Easing.InCubic }
                NumberAnimation { property: "scale"; to: 0.94; duration: 280; easing.type: Easing.InCubic }
            }
        }
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
        }
    }
}
