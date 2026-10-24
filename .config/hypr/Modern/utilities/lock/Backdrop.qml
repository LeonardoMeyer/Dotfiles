import QtQuick
import QtQuick.Effects

// The lock's background: the wallpaper, blurred and dimmed, pushed in slightly by `amount` (1 = fully locked).
// The lock surfaces and the handoff layers draw the same one, so the switch between them can't be seen.
// The blur itself never animates (that re-blurs every frame and stutters); only opacity and scale move.
Item {
    id: b

    property real amount: 1

    Image {
        id: wall
        anchors.fill: parent
        visible: false
        source: Lock.wallpaper
        fillMode: Image.PreserveAspectCrop
        // Blurred anyway, so decoded small and once: every monitor and layer shares the cached copy.
        sourceSize.width: 1280
        asynchronous: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        scale: 1 + 0.035 * b.amount
        blurEnabled: true
        blurMax: 64
        blur: 1
        saturation: 0.12
        autoPaddingEnabled: false
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.28
    }
}
