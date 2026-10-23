import QtQuick
import "../common"

// One shape that is a search button when closed and the search field when open: the width grows with a fixed
// half-height radius, so the circle stretches into an oval instead of being swapped for another widget.
Item {
    id: pill

    property bool expanded: false
    property real fullWidth: 240
    property string hint: ""
    property string placeholder: "Search apps"
    property alias text: input.text
    readonly property alias input: input
    // Called with each key event before the field sees it; returning true consumes the key.
    property var keyHandler: null
    signal clicked()

    // Opening stretches out and settles with the faintest overshoot; closing eases straight back.
    property real open: 0
    onExpandedChanged: {
        morph.stop()
        morph.from = open
        morph.to = expanded ? 1 : 0
        morph.duration = Theme.ms(expanded ? 420 : 280)
        morph.easing.bezierCurve = expanded ? Theme.settle : Theme.leave
        morph.start()
    }
    NumberAnimation { id: morph; target: pill; property: "open"; easing.type: Easing.BezierSpline }

    // Peaks mid-morph; the glyph tips slightly as the shape stretches.
    readonly property real wobble: Math.sin(Math.max(0, Math.min(1, open)) * Math.PI)

    // 0 until `from` of the morph, then ramps to 1, so the text arrives once there is room for it.
    function stage(from) {
        return Math.max(0, Math.min(1, (open - from) / (1 - from)))
    }

    implicitHeight: 36
    width: height + (fullWidth - height) * open

    Rectangle {
        id: shape
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: parent.height
        radius: height / 2
        color: Theme.alpha(Theme.fg, (area.containsMouse && !pill.expanded ? 0.13 : 0.07) + 0.03 * pill.stage(0))
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.55 * pill.stage(0.2))
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }

    Text {
        id: glyph
        x: (pill.height - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        text: ""
        font.family: Theme.sans
        font.pixelSize: Math.round(pill.height * 0.4)
        rotation: -8 * pill.wobble
        scale: area.pressed ? 0.9 : 1
        color: pill.open > 0.5 ? Theme.accent : (area.containsMouse ? Theme.bright : Theme.fg)
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }

    Item {
        id: field
        anchors.left: parent.left
        anchors.leftMargin: pill.height - 4
        anchors.right: parent.right
        anchors.rightMargin: pill.height * 0.4
        height: parent.height
        clip: true
        // Stays visible while transparent: an invisible item can't hold keyboard focus.
        opacity: pill.stage(0.35)

        TextInput {
            id: input
            anchors.left: parent.left
            anchors.right: hintText.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.sans
            font.pixelSize: 14
            color: Theme.bright
            selectionColor: Theme.alpha(Theme.accent, 0.5)
            selectedTextColor: Theme.bright
            clip: true
            // A hidden field keeps focus so the first keystroke both opens it and lands in it.
            cursorVisible: activeFocus && pill.expanded
            Keys.onPressed: event => { if (pill.keyHandler && pill.keyHandler(event)) event.accepted = true }
            transform: Translate { x: -14 * (1 - pill.stage(0.35)) }
        }

        Text {
            anchors.left: input.left
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: pill.placeholder
            font: input.font
            color: Theme.dim
            transform: Translate { x: -14 * (1 - pill.stage(0.35)) }
        }

        Text {
            id: hintText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, field.width * 0.45)
            elide: Text.ElideRight
            text: pill.hint !== "" ? "↵  " + pill.hint : ""
            font.family: Theme.sans
            font.pixelSize: 11
            color: Theme.dim
            opacity: pill.stage(0.6)
        }
    }

    // While closed the whole circle is a button; once open, clicks go straight to the text field.
    MouseArea {
        id: area
        anchors.fill: parent
        enabled: !pill.expanded
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
