import QtQuick
import "../common"

// Vertical wheel in the style of the settings sheet's Waybar and color wheels: the centered entry is full size on
// an accent plate, neighbours shrink and fade with distance. Built for thousands of entries: only the rows near the
// center exist, and each row maps to whichever entry sits at its offset, so scrolling never creates anything.
// Rows carry no animations of their own (everything is a function of distance), which keeps the recycling seamless.
// entries: [{ n, k, d }]
Item {
    id: wheel

    property var entries: []
    property int cur: 0
    // The launcher stays built while closed; nothing should keep animating then.
    property bool animate: true
    property real pos: 0
    signal activated(int index)

    // Where the centered entry sits (0 = top, 1 = bottom); above the middle, since the list starts at its first entry.
    property real centerFrac: 0.36
    readonly property int n: entries.length
    readonly property real pitch: Math.min(64, Math.max(46, height / 6.2))
    readonly property real rowH: Math.round(pitch * 0.74)
    readonly property int reach: 5

    // Slow free-running phase for the centered entry's subtle drift, as in the settings wheel.
    property real t: 0
    NumberAnimation on t {
        from: 0
        to: Math.PI * 2
        duration: 3200
        loops: Animation.Infinite
        running: wheel.animate && wheel.visible && wheel.n > 0
    }

    // Entries settle in from below when the list is replaced (opening, a new search).
    property real intro: 1
    NumberAnimation { id: introAnim; target: wheel; property: "intro"; from: 0; to: 1; duration: Theme.ms(420); easing.type: Easing.OutCubic }

    function reset() {
        settle.stop()
        cur = 0
        pos = 0
        introAnim.restart()
    }

    function step(d) {
        if (n === 0) return
        const next = Math.max(0, Math.min(n - 1, cur + d))
        if (next === cur) return
        cur = next
        settle.stop()
        settle.to = cur
        settle.start()
    }

    NumberAnimation { id: settle; target: wheel; property: "pos"; duration: Theme.ms(380); easing.type: Easing.OutCubic }

    property real wheelAcc: 0
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            // Trackpads send many small deltas; a notch is one step either way.
            wheel.wheelAcc += event.angleDelta.y
            while (Math.abs(wheel.wheelAcc) >= 120) {
                wheel.step(wheel.wheelAcc > 0 ? -1 : 1)
                wheel.wheelAcc -= wheel.wheelAcc > 0 ? 120 : -120
            }
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        clip: true

        Repeater {
            model: wheel.reach * 2 + 1

            Item {
                id: row
                required property int index
                readonly property int idx: Math.round(wheel.pos) - wheel.reach + index
                readonly property bool live: idx >= 0 && idx < wheel.n
                readonly property var e: live ? wheel.entries[idx] : null
                readonly property real d: idx - wheel.pos
                readonly property real ad: Math.abs(d)
                // 1 when exactly centered, 0 once a full step away (smoothstepped).
                readonly property real lift: Math.max(0, 1 - ad)
                readonly property real ease: lift * lift * (3 - 2 * lift)

                visible: live && ad < 4.4
                width: stage.width - 24
                height: wheel.rowH
                x: (stage.width - width) / 2
                y: stage.height * wheel.centerFrac - height / 2 + d * wheel.pitch * (1 - 0.05 * Math.min(ad, 3)) + (1 - wheel.intro) * 18 * (1 + Math.min(ad, 3))
                   + Math.sin(wheel.t) * 1.2 * ease
                scale: Math.max(0.7, 1 - 0.08 * ad)
                opacity: Math.max(0, 1 - 0.27 * ad) * Math.min(1, wheel.intro * (1.6 - 0.12 * Math.min(ad, 4)))
                z: 10 - ad

                Rectangle {
                    anchors.fill: parent
                    radius: 10 + 2 * row.ease
                    color: Qt.rgba(
                        Theme.fg.r + (Theme.accent.r - Theme.fg.r) * row.ease,
                        Theme.fg.g + (Theme.accent.g - Theme.fg.g) * row.ease,
                        Theme.fg.b + (Theme.accent.b - Theme.fg.b) * row.ease,
                        0.045 + 0.215 * row.ease)
                    border.width: 1
                    border.color: Theme.alpha(Theme.accent, 0.55 * row.ease)
                }

                Text {
                    id: name
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width * 0.55)
                    elide: Text.ElideRight
                    text: row.e ? row.e.n : ""
                    font.family: Theme.sans
                    font.pixelSize: 15
                    color: Qt.rgba(
                        Theme.fg.r + (Theme.bright.r - Theme.fg.r) * row.ease,
                        Theme.fg.g + (Theme.bright.g - Theme.fg.g) * row.ease,
                        Theme.fg.b + (Theme.bright.b - Theme.fg.b) * row.ease, 1)
                }

                Text {
                    anchors.left: name.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    text: !row.e ? "" : row.e.k === "alias" ? "= " + row.e.d : row.e.k === "function" ? "function" : row.e.d
                    font.family: Theme.sans
                    font.pixelSize: 11
                    color: Theme.dim
                    opacity: 0.55 + 0.45 * row.ease
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    // Off-center rows come to the center; the centered one runs.
                    onClicked: {
                        if (row.idx === wheel.cur) wheel.activated(row.idx)
                        else wheel.step(row.idx - wheel.cur)
                    }
                }
            }
        }
    }
}
