import QtQuick
import Quickshell
import Quickshell.Widgets

// Every app keeps one icon for the life of the shell. Filtering only hands out slots: an icon that still matches
// stays fully drawn and glides to its new slot, an icon that stops matching fades where it stands, and one that
// starts matching again fades in at its new slot. Nothing is rebuilt or reloaded per keystroke.
Flickable {
    id: grid

    property var apps: []           // [{ id, entry, ... }], fixed order
    property var slots: ({})        // id -> slot index for the current results
    property int count: 0
    property int selected: 0
    property int cols: 4
    property real cell: 68
    property real gap: 14
    // The highlight's margin around a cell; fixed by the panel so spacing changes never resize it.
    property real hlPad: 5
    property string emptyText: ""
    // Hover only selects after the pointer itself moves, so icons gliding under a resting cursor
    // (or keyboard navigation) never steal the selection.
    property bool mouseMoved: false
    // 0 -> 1 on open: icons rise in row by row.
    property real intro: 1
    signal launch(var app)
    signal hover(int slot)

    readonly property real pitch: cell + gap
    readonly property real inset: Math.max(hlPad + 4, Math.round(gap * 0.4))
    readonly property real side: Math.round((width - (cols * cell + (cols - 1) * gap)) / 2)
    readonly property int rows: Math.ceil(count / cols)

    function slotX(s) { return side + (s % cols) * pitch }
    function slotY(s) { return inset + Math.floor(s / cols) * pitch }

    clip: true
    contentWidth: width
    contentHeight: Math.max(height, inset * 2 + rows * pitch - gap)
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    function scrollTo(y) {
        scrollAnim.stop()
        scrollAnim.from = contentY
        scrollAnim.to = Math.max(0, Math.min(contentHeight - height, y))
        scrollAnim.start()
    }

    // Keeps the selected row in view, with a little of the next row showing.
    function reveal(s) {
        if (s < 0) return
        const top = slotY(s) - inset
        const bottom = slotY(s) + cell + inset
        const target = scrollAnim.running ? scrollAnim.to : contentY
        if (top < target) scrollTo(top)
        else if (bottom > target + height) scrollTo(bottom - height)
    }

    NumberAnimation { id: scrollAnim; target: grid; property: "contentY"; duration: 260; easing.type: Easing.OutCubic }

    onSelectedChanged: reveal(selected)

    HoverHandler {
        onPointChanged: grid.mouseMoved = true
    }

    // One row per wheel notch, eased; touchpads scroll by their own pixel deltas.
    MouseArea {
        width: grid.contentWidth
        height: grid.contentHeight
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            if (event.pixelDelta.y !== 0) {
                scrollAnim.stop()
                grid.contentY = Math.max(0, Math.min(grid.contentHeight - grid.height, grid.contentY - event.pixelDelta.y))
            } else {
                const base = scrollAnim.running ? scrollAnim.to : grid.contentY
                grid.scrollTo(base - event.angleDelta.y / 120 * grid.pitch)
            }
        }
    }

    // One highlight glides between icons; it is also the hover background.
    Rectangle {
        x: grid.slotX(grid.selected) - grid.hlPad
        y: grid.slotY(grid.selected) - grid.hlPad
        width: grid.cell + grid.hlPad * 2
        height: width
        radius: 10 + grid.hlPad
        color: Theme.alpha(Theme.accent, 0.26)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.55)
        opacity: grid.count > 0 ? 1 : 0
        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
    }

    Repeater {
        model: grid.apps

        Item {
            id: tile
            required property var modelData
            readonly property int slot: grid.slots[modelData.id] ?? -1
            readonly property real layoutKey: grid.side + grid.cell * 1000
            readonly property string src: Quickshell.iconPath(modelData.icon, true)
                || Quickshell.iconPath("application-x-executable", true)

            // Presence eases in a little slower than it leaves, so results bloom rather than pop.
            property real present: slot >= 0 ? 1 : 0
            Behavior on present { NumberAnimation { duration: tile.slot >= 0 ? 300 : 200; easing.type: Easing.OutCubic } }

            // Row-by-row rise on open; capped so long lists don't wait on their last rows.
            readonly property real rise: {
                const row = Math.min(6, Math.floor(Math.max(0, slot) / grid.cols))
                const e = Math.max(0, Math.min(1, (grid.intro - row * 0.07) / 0.58))
                return 1 - Math.pow(1 - e, 3)
            }

            width: grid.cell
            height: grid.cell
            visible: opacity > 0.01
            opacity: present * rise
            scale: 0.92 + 0.08 * present
            transform: Translate { y: 10 * (1 - tile.rise) }

            Behavior on x { id: moveX; NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }
            Behavior on y { id: moveY; NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }

            function jumpTo(nx, ny) {
                moveX.enabled = false
                moveY.enabled = false
                x = nx
                y = ny
                moveX.enabled = true
                moveY.enabled = true
            }

            // Reads slot, not a derived flag: this runs from onSlotChanged, before bindings that depend on slot update.
            function place(instant) {
                if (slot < 0) return
                // Hidden (or still fading out): appear at the new slot rather than travel from the old one.
                // A visible icon never fades to move, so it can't look like it is reloading.
                if (instant || present < 0.2) jumpTo(grid.slotX(slot), grid.slotY(slot))
                else { x = grid.slotX(slot); y = grid.slotY(slot) }
            }
            Component.onCompleted: place(true)
            onSlotChanged: place(false)
            onLayoutKeyChanged: place(true)

            IconImage {
                id: icon
                anchors.centerIn: parent
                implicitSize: Math.round(grid.cell * 0.74)
                source: tile.src
                asynchronous: true
                mipmap: true
                visible: tile.src !== "" && status !== Image.Error
                scale: hit.containsMouse ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }

            // Last resort when not even the generic icon resolves: the app's initial in the accent color.
            Text {
                anchors.centerIn: parent
                visible: !icon.visible
                text: tile.modelData.name.charAt(0).toUpperCase()
                font.family: Theme.sans
                font.pixelSize: Math.round(grid.cell * 0.46)
                color: Theme.accent
            }

            MouseArea {
                id: hit
                anchors.fill: parent
                enabled: tile.slot >= 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: if (grid.mouseMoved) grid.hover(tile.slot)
                onPositionChanged: if (grid.mouseMoved && grid.selected !== tile.slot) grid.hover(tile.slot)
                onClicked: grid.launch(tile.modelData)
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: grid.height * 0.32
        spacing: 8
        opacity: grid.count === 0 ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 240 } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ""
            font.family: Theme.sans
            font.pixelSize: 26
            color: Theme.alpha(Theme.fg, 0.25)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: grid.width - 40
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            text: grid.emptyText
            font.family: Theme.sans
            font.pixelSize: 13
            color: Theme.dim
        }
    }
}
