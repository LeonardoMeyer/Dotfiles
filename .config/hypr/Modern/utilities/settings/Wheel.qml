import QtQuick

// Vertical wheel: scroll (or arrow keys) to turn it, click or Enter to apply.
// entries: [{ id, name, sub, colors?: [hex...], image?: url }]. Colors render as discrete swatch pills
// that rise and spread on the centered entry; images render in a rounded plate.
Item {
    id: wheel

    property var entries: []
    property string activeId: ""
    property real barH: 0
    property real maxPitch: 140
    property real fixedPitch: 0
    // Where the centered entry sits in the stage (0 = top, 1 = bottom); lower leaves less dead space above the first entry.
    property real centerFrac: 0.5
    property bool showHint: true
    signal applied(string id)

    readonly property int n: entries.length
    readonly property int activeIndex: Math.max(0, entries.findIndex(e => e.id === activeId))

    // Shortest signed distance around the loop, in [-n/2, n/2). Every entry is drawn once, at this offset.
    // The seam (where an entry jumps from one end to the other) sits half a step off the rest positions,
    // so every entry is fully visible at rest, including the far one on even-sized lists.
    readonly property real lo: -n / 2 - (n % 2 === 0 ? 0.5 : 0)
    function wrap(x) {
        return n > 0 ? (((x - lo) % n) + n) % n + lo : 0
    }
    function mod(i) {
        return n > 0 ? ((i % n) + n) % n : 0
    }
    readonly property real pitch: fixedPitch > 0 ? fixedPitch : Math.min(maxPitch, Math.max(54, stage.height / 4.6))
    readonly property real rowH: barH > 0 ? barH : Math.round(pitch * 0.68)
    readonly property var wave: [0.62, 0.86, 0.7, 1, 0.78, 0.94, 0.66, 0.84]

    property int cur: 0
    property real pos: 0
    property real wheelAcc: 0

    // The panel's key handling drives whichever wheel is on the current page.
    Component.onCompleted: {
        cur = activeIndex
        pos = cur
        Store.wheels = Store.wheels.concat([wheel])
        introAnim.start()
    }
    Component.onDestruction: Store.wheels = Store.wheels.filter(w => w !== wheel)

    // Entries fan out from the centered one when the wheel appears.
    property real intro: 0
    property int introDelay: 0
    SequentialAnimation {
        id: introAnim
        PauseAnimation { duration: wheel.introDelay }
        NumberAnimation { target: wheel; property: "intro"; from: 0; to: 1; duration: 620; easing.type: Easing.OutCubic }
    }
    onActiveIndexChanged: cur = cur + wrap(activeIndex - mod(cur))
    onEntriesChanged: { cur = mod(cur); if (!settleAnim.running) pos = cur }
    onCurChanged: {
        settleAnim.stop()
        settleAnim.to = cur
        settleAnim.start()
    }

    NumberAnimation { id: settleAnim; target: wheel; property: "pos"; duration: 380; easing.type: Easing.OutCubic }

    function step(d) {
        if (n > 1) cur += d
    }

    function apply(i) {
        const idx = mod(i)
        cur = cur + wrap(idx - mod(cur))
        const e = entries[idx]
        if (e && e.id !== activeId) applied(e.id)
    }

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
        anchors.bottomMargin: wheel.showHint ? 34 : 0
        clip: true

        Repeater {
            model: wheel.entries

            Item {
                id: item
                required property var modelData
                required property int index
                readonly property real d: wheel.wrap(index - wheel.pos)
                readonly property real ad: Math.abs(d)
                readonly property bool active: modelData.id === wheel.activeId
                readonly property bool centered: wheel.mod(Math.round(wheel.pos)) === index
                readonly property bool isImage: !!modelData.image

                // An entry fades out as it nears the seam and back in on the other side, so it never shows twice or pops.
                readonly property real edge: Math.max(0, Math.min(1, Math.min(d - wheel.lo, wheel.lo + wheel.n - d) / 0.5))
                visible: ad < 3.6 && edge > 0.01
                width: stage.width - 28
                height: wheel.rowH
                x: (stage.width - width) / 2
                y: stage.height * wheel.centerFrac - height / 2 + d * wheel.pitch * (1 - 0.05 * Math.min(ad, 3)) * wheel.intro
                scale: Math.max(0.62, 1 - 0.09 * ad)
                opacity: Math.max(0, 1 - 0.26 * ad) * Math.min(1, wheel.intro * 1.6) * edge
                z: 10 - ad

                Row {
                    id: cells
                    visible: !item.isImage
                    anchors.fill: parent
                    spacing: item.centered ? 8 : 4
                    Behavior on spacing { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    Repeater {
                        model: item.modelData.colors || []

                        Item {
                            id: cell
                            required property string modelData
                            required property int index
                            readonly property int n: (item.modelData.colors || []).length
                            width: (cells.width - cells.spacing * (n - 1)) / n
                            height: cells.height

                            Rectangle {
                                width: parent.width
                                height: parent.height * (item.centered ? wheel.wave[cell.index % 8] : 0.5 + 0.18 * wheel.wave[cell.index % 8])
                                anchors.verticalCenter: parent.verticalCenter
                                radius: Math.min(width / 2, 10)
                                color: cell.modelData
                                Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }

                RoundedImage {
                    visible: item.isImage
                    anchors.fill: parent
                    radius: 10
                    source: item.isImage ? item.modelData.image : ""
                }

                // In-use marker, visible even when the entry is off-center.
                Rectangle {
                    visible: item.active
                    width: 7
                    height: 7
                    radius: 4
                    x: -12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.bright
                    border.width: 2
                    border.color: Theme.alpha(Theme.bg, 0.55)
                }

                Text {
                    anchors.top: parent.bottom
                    anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: item.centered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    text: item.modelData.name + (item.modelData.sub ? "  ·  " + item.modelData.sub : "")
                    font.family: Theme.sans
                    font.pixelSize: 13
                    color: Theme.bright
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wheel.apply(item.index)
                }
            }
        }
    }

    Text {
        visible: wheel.showHint
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        text: "scroll to browse  ·  click or Enter to apply"
        font.family: Theme.sans
        font.pixelSize: 10
        font.letterSpacing: 0.8
        color: Theme.dim
    }
}
