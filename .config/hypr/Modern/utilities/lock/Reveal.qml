import QtQuick

// A module's entrance, exit and on/off: it rises in on its slice of Lock.t, and switching it off (settings, idle)
// fades it out and folds its height away so the modules around it close up smoothly.
Item {
    id: r

    property real delay: 0
    property bool on: true
    property real u: 1
    default property alias content: body.data

    readonly property real p: Lock.seg(delay)
    property real shown: on ? 1 : 0
    Behavior on shown { NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Lock.settle } }

    implicitWidth: body.childrenRect.width
    implicitHeight: body.childrenRect.height * shown
    width: implicitWidth
    height: implicitHeight
    // Leaving, everything sinks a little and fades together.
    opacity: p * shown * (1 - Lock.out)
    visible: opacity > 0.001
    scale: (0.96 + 0.04 * p) * (1 - 0.03 * Lock.out)
    transform: Translate { y: (1 - r.p) * 26 * r.u + (1 - r.shown) * -8 * r.u + Lock.out * 14 * r.u }

    Item {
        id: body
        width: childrenRect.width
        height: childrenRect.height
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
