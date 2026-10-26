import QtQuick

Item {
    id: d

    property string value
    property real size: 100
    property color color: "#ffffff"
    property int weight: Font.Light
    property string cur: value

    width: cell.advanceWidth * Math.max(1, value.length)
    height: label.implicitHeight

    TextMetrics { id: cell; font: label.font; text: "0" }

    Text {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        text: d.cur
        font.family: Lock.sans
        font.pixelSize: d.size
        font.weight: d.weight
        color: d.color
    }

    onValueChanged: if (value !== cur) flip.restart()

    SequentialAnimation {
        id: flip
        ParallelAnimation {
            NumberAnimation { target: label; property: "y"; to: -d.size * 0.22; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: label; property: "opacity"; to: 0; duration: 180 }
        }
        ScriptAction { script: { d.cur = d.value; label.y = d.size * 0.22 } }
        ParallelAnimation {
            NumberAnimation { target: label; property: "y"; to: 0; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Lock.settle }
            NumberAnimation { target: label; property: "opacity"; to: 1; duration: 300 }
        }
    }
}
