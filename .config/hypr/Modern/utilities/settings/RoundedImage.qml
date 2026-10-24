import QtQuick
import QtQuick.Effects
import "../common"

// Image clipped to rounded corners.
Item {
    id: root

    property url source
    property real radius: Theme.r(8)
    property int fillMode: Image.PreserveAspectFit
    property color backdrop: "transparent"

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }

    Item {
        id: art
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle { anchors.fill: parent; color: root.backdrop }

        Image {
            anchors.fill: parent
            source: root.source
            fillMode: root.fillMode
            sourceSize.width: Math.round(root.width * 2)
            asynchronous: true
            smooth: true
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: art
        maskEnabled: true
        maskSource: mask
    }
}
