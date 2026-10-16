import QtQuick

Item {
    id: control

    property var def
    readonly property var raw: Store.values[def.key]
    readonly property bool ready: raw !== undefined && raw !== null
    readonly property real step: def.step
    readonly property int decimals: {
        const s = String(step)
        const i = s.indexOf(".")
        return i < 0 ? 0 : s.length - i - 1
    }
    property real dragValue: 0
    property real lastSent: 0
    readonly property real shown: area.pressed ? dragValue : (ready ? raw : def.min)
    readonly property real ratio: Math.max(0, Math.min(1, (shown - def.min) / (def.max - def.min)))
    readonly property bool hot: area.containsMouse || area.pressed

    implicitHeight: 58
    opacity: ready ? 1 : 0.35

    Text {
        x: Theme.pad
        y: 10
        text: control.def.label
        font.family: Theme.sans
        font.pixelSize: 13
        color: control.hot ? Theme.bright : Theme.fg
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: Theme.pad
        y: 10
        text: Number(control.shown).toFixed(control.decimals) + control.def.unit
        font.family: Theme.sans
        font.pixelSize: 13
        color: Theme.accent
    }

    Rectangle {
        id: track
        x: Theme.pad
        y: 38
        width: parent.width - Theme.pad * 2
        height: 4
        radius: 2
        color: Theme.alpha(Theme.fg, 0.16)

        Rectangle {
            width: parent.width * control.ratio
            height: parent.height
            radius: 2
            color: Theme.accent
        }

        Rectangle {
            x: parent.width * control.ratio - width / 2
            y: -4
            width: 12
            height: 12
            radius: 6
            color: Theme.bright
            scale: control.hot ? 1 : 0
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: control.ready
        cursorShape: Qt.PointingHandCursor

        function update(x) {
            const r = Math.max(0, Math.min(1, (x - track.x) / track.width))
            let v = control.def.min + Math.round(r * (control.def.max - control.def.min) / control.step) * control.step
            v = Number(Math.max(control.def.min, Math.min(control.def.max, v)).toFixed(control.decimals))
            control.dragValue = v
            if (v !== control.lastSent) {
                control.lastSent = v
                Store.set(control.def.key, v)
            }
        }

        onPressed: mouse => { control.lastSent = control.raw; update(mouse.x) }
        onPositionChanged: mouse => { if (pressed) update(mouse.x) }
    }

    // Right-click puts the setting back to the profile's own value.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: Store.reset(control.def.key)
    }
}
