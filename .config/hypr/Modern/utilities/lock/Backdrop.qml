import QtQuick
import QtQuick.Effects

// only opacity/scale animate, re-blurring every frame stutters
Item {
    id: b

    property real amount: 1

    Image {
        id: wall
        anchors.fill: parent
        visible: false
        source: Lock.wallpaper
        fillMode: Image.PreserveAspectCrop
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
