import QtQuick
import QtQuick.Effects

// the blurred dark wallpaper behind home, overview and lock (boot has its own copy, it runs alone).
// t is how open it is. never fully 0, Qt skips the first blur and that's some bullshit
Item {
    id: b

    property real t: 1
    property real zoom: 0.035 * t
    property real dim: 0.22 * t
    property alias source: wall.source
    property alias status: wall.status

    opacity: Math.max(0.001, Math.min(1, t * 2.5))

    Image {
        id: wall
        anchors.fill: parent
        visible: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: b.width
        sourceSize.height: b.height
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        scale: 1 + b.zoom
        blurEnabled: true
        blurMax: 64
        blur: 1
        brightness: -0.1
        saturation: 0.12
    }
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: b.dim
    }
}
