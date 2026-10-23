import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../common"

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

    Timer { id: linger; interval: Theme.ms(600); onTriggered: win.alive = false }

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
            readonly property real secs: modelData.expireTimeout > 0 ? modelData.expireTimeout / 1000 : 6
            readonly property bool sticky: modelData.expireTimeout === 0
                || (modelData.urgency === NotificationUrgency.Critical && modelData.expireTimeout < 0)
            property real remain: 1

            // 0 = collapsed at the left edge, 1 = fully open. Can overshoot past 1 on entry.
            property real reveal: 0
            readonly property real r: Math.max(0, Math.min(1, reveal))

            width: list.width
            // Slot height follows the reveal, so the stack makes room (and closes the gap) smoothly.
            height: card.height * r

            // Entry: morph out of the left edge with a soft overshoot.
            NumberAnimation {
                id: enter
                target: slot
                property: "reveal"
                from: 0
                to: 1
                duration: Theme.ms(560)
                easing.type: Easing.OutBack
                easing.overshoot: 1.2 
            }
            Component.onCompleted: enter.start()

            // Exit: hold the delegate alive, fold back into the left edge, then release it.
            ListView.onRemove: SequentialAnimation {
                PropertyAction { target: slot; property: "ListView.delayRemove"; value: true }
                NumberAnimation {
                    target: slot
                    property: "reveal"
                    to: 0
                    duration: Theme.ms(300)
                    easing.type: Easing.InOutCubic
                }
                PropertyAction { target: slot; property: "ListView.delayRemove"; value: false }
            }

            Item {
                id: morph
                width: parent.width
                height: card.height
                anchors.bottom: parent.bottom
                opacity: Math.max(0, Math.min(1, slot.reveal * 2.2))
                x: -56 * win.u * (1 - slot.r)

                // Covers the full card area, not just the text or buttons inside it.
                HoverHandler { id: hover }

                transform: Scale {
                    origin.x: 0
                    origin.y: morph.height / 2
                    xScale: 0.35 + 0.65 * slot.reveal
                    yScale: 0.72 + 0.28 * slot.reveal
                }

                NotificationCard {
                    id: card
                    width: parent.width
                    n: slot.modelData
                    shell: win.shell
                    u: win.u
                    popup: true
                    progress: slot.sticky ? -1 : slot.remain
                    scale: hover.hovered ? 1.015 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.ms(180); easing.type: Easing.OutCubic } }
                }
            }

            NumberAnimation {
                target: slot
                property: "remain"
                from: 1
                to: 0
                duration: slot.secs * 1000
                running: !slot.sticky
                paused: hover.hovered
                onFinished: win.shell.expirePopup(slot.modelData)
            }
        }
    }
}
