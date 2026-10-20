import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "Schema.js" as Schema

// Hyprland settings sheet: slides in from the left edge below waybar, toggled with Alt+S (see settings.sh).
// The right edge drags to resize; the width is remembered between sessions.
ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property real defaultFrac: 1 / 3
    readonly property real minFrac: 0.2
    readonly property real maxFrac: 0.6

    // The window stays mapped (empty input region) so opening never waits on surface creation.
    property bool active: false
    property bool leaving: false
    property real t: 0
    property var targetScreen: null

    property real frac: defaultFrac
    property real dragFrac: defaultFrac
    property bool dragging: false
    property string page: "profile"
    readonly property var current: Schema.PAGES.find(p => p.id === page) || Schema.PAGES[0]
    readonly property real screenW: (win.screen ? win.screen.width : 1600)

    FileView {
        id: uiFile
        path: root.home + "/.local/state/hypr-settings/ui.json"
        blockLoading: true
    }

    Component.onCompleted: {
        try {
            const ui = JSON.parse(uiFile.text())
            if (typeof ui.wfrac === "number") frac = Math.max(minFrac, Math.min(maxFrac, ui.wfrac))
            if (ui.page && Schema.PAGES.some(p => p.id === ui.page)) page = ui.page
        } catch (e) {}
        dragFrac = frac
        targetScreen = focusedScreen()
        Store.refresh()
    }

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor
        return Quickshell.screens.find(s => s.name === mon?.name) ?? Quickshell.screens[0]
    }

    function show() {
        if (active && !leaving) return
        const scr = focusedScreen()
        if (!active && scr !== targetScreen) {
            // A different monitor needs a new surface; give it a moment before sliding in.
            targetScreen = scr
            moveDelay.restart()
            return
        }
        begin()
    }

    function begin() {
        leaving = false
        active = true
        enterSerial++
        keyRoot.forceActiveFocus()
        animateTo(1)
    }

    function close() {
        if (!active || leaving) return
        leaving = true
        animateTo(0)
    }

    function toggle() {
        if (active && !leaving) close()
        else show()
    }

    function stepPage(d) {
        const i = Schema.PAGES.findIndex(p => p.id === page)
        selectPage(Schema.PAGES[(i + d + Schema.PAGES.length) % Schema.PAGES.length].id)
    }

    function moveSelection(d) {
        const w = Store.wheels.length > 0 ? Store.wheels[Store.wheels.length - 1] : null
        if (w) { w.step(d); return }
        const s = scrollAnim
        s.stop()
        s.from = scroller.contentY
        s.to = Math.max(0, Math.min(scroller.contentHeight - scroller.height, scroller.contentY + d * 90))
        s.start()
    }

    // Which way the last tab change moved, and a counter that replays every entrance (also on open).
    property int pageDir: 1
    property int enterSerial: 0

    function selectPage(id) {
        if (id === page) return
        const from = Schema.PAGES.findIndex(p => p.id === page)
        const to = Schema.PAGES.findIndex(p => p.id === id)
        pageDir = to >= from ? 1 : -1
        page = id
        Store.saveUi("page", id)
        keyRoot.forceActiveFocus()
    }

    // Expo-out in, a quick ease-in out: the sheet decelerates into place and leaves briskly.
    function animateTo(target) {
        tween.stop()
        tween.from = t
        tween.to = target
        tween.duration = target === 1 ? 380 : 240
        tween.easing.type = Easing.BezierSpline
        tween.easing.bezierCurve = target === 1 ? [0.16, 1, 0.3, 1, 1, 1] : [0.5, 0, 0.75, 0, 1, 1]
        tween.start()
    }

    Timer { id: moveDelay; interval: 90; onTriggered: root.begin() }

    NumberAnimation {
        id: tween
        target: root
        property: "t"
        onFinished: {
            if (root.leaving) Quickshell.quit()
            else Store.refresh()
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.close() }
        function page(id: string): void { root.selectPage(id); root.show() }
    }

    // Rows appear only when they would do something: a dependency is met, the hardware exists, styles are present.
    function controlShown(c, values, caps, waybar) {
        if (c.type === "waybar" && (waybar.styles || []).length === 0) return false
        return Schema.shown(c, values, caps)
    }

    function sectionVisible(sec, values, caps, waybar) {
        return sec.controls.some(c => controlShown(c, values, caps, waybar))
    }

    function firstShown(controls, values, caps, waybar) {
        return controls.findIndex(c => controlShown(c, values, caps, waybar))
    }

    function source(type) {
        return "Setting" + type.charAt(0).toUpperCase() + type.slice(1) + ".qml"
    }

    PanelWindow {
        id: win
        screen: root.targetScreen ?? Quickshell.screens[0]
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        // Normal exclusion keeps the sheet below waybar's reserved strip.
        exclusionMode: ExclusionMode.Normal
        // While open the whole surface takes input, so a click outside the sheet can close it.
        mask: Region { item: root.active && !root.leaving ? keyRoot : null }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "settings-panel"
        WlrLayershell.keyboardFocus: root.active && !root.leaving ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Item {
            id: keyRoot
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.close()
            // Arrows and vim keys: h/l (or left/right) change tab, j/k (or down/up) turn the wheel or scroll the page.
            Keys.onPressed: event => {
                const k = event.key
                if (k === Qt.Key_Left || k === Qt.Key_H) root.stepPage(-1)
                else if (k === Qt.Key_Right || k === Qt.Key_L) root.stepPage(1)
                else if (k === Qt.Key_Down || k === Qt.Key_J) root.moveSelection(1)
                else if (k === Qt.Key_Up || k === Qt.Key_K) root.moveSelection(-1)
                else if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && Store.wheels.length > 0) Store.wheels[Store.wheels.length - 1].apply(Store.wheels[Store.wheels.length - 1].cur)
                else { event.accepted = false; return }
                event.accepted = true
            }

            MouseArea {
                anchors.fill: parent
                onPressed: root.close()
            }

            Item {
                id: card
                visible: root.active
                width: Math.round(root.screenW * (root.dragging ? root.dragFrac : root.frac))
                height: parent.height
                x: (root.t - 1) * width

                // Clicks on bare sheet must not reach the close-on-outside-click backdrop.
                MouseArea { anchors.fill: parent }

                // Matches Hyprland: 10px rounding, no border, translucent background over compositor blur.
                // The left side is pushed off-screen so only the right corners are rounded.
                Rectangle {
                    x: -12
                    width: parent.width + 12
                    height: parent.height
                    radius: 10
                    color: Theme.alpha(Theme.bg, 0.64)
                }

                Item {
                    id: content
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 18

                    Text {
                        id: title
                        y: 16
                        text: root.current.label
                        font.family: Theme.sans
                        font.pixelSize: 20
                        color: Theme.bright

                        transform: Translate { id: titleShift }

                        Connections {
                            target: root
                            function onPageChanged() { titleAnim.restart() }
                        }

                        ParallelAnimation {
                            id: titleAnim
                            NumberAnimation { target: title; property: "opacity"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
                            NumberAnimation { target: titleShift; property: "x"; from: 14 * root.pageDir; to: 0; duration: 380; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: title.verticalCenter
                        text: "Hyprland · Alt+S"
                        font.family: Theme.sans
                        font.pixelSize: 11
                        color: Theme.dim
                    }

                    Item {
                        id: tabs
                        y: title.y + title.height + 14
                        width: parent.width
                        height: 34
                        readonly property real gap: 6
                        readonly property real cell: (width - gap * (Schema.PAGES.length - 1)) / Schema.PAGES.length
                        readonly property int index: Math.max(0, Schema.PAGES.findIndex(p => p.id === root.page))

                        // One highlight that glides between tabs instead of each tab recoloring.
                        Rectangle {
                            width: tabs.cell
                            height: parent.height
                            radius: 9
                            x: tabs.index * (tabs.cell + tabs.gap)
                            color: Theme.alpha(Theme.accent, 0.42)
                            Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                        }

                        Repeater {
                            model: Schema.PAGES

                            Item {
                                id: tab
                                required property var modelData
                                required property int index
                                readonly property bool on: root.page === modelData.id
                                x: index * (tabs.cell + tabs.gap)
                                width: tabs.cell
                                height: tabs.height

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 9
                                    color: Theme.alpha(Theme.fg, tab.on ? 0 : (tabArea.containsMouse ? 0.12 : 0.05))
                                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: tab.modelData.icon
                                    font.family: Theme.sans
                                    font.pixelSize: 15
                                    scale: tab.on ? 1.12 : 1
                                    color: tab.on || tabArea.containsMouse ? Theme.bright : Theme.fg
                                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                                }

                                MouseArea {
                                    id: tabArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectPage(tab.modelData.id)
                                }
                            }
                        }
                    }

                    Flickable {
                        id: scroller
                        anchors.top: tabs.bottom
                        anchors.topMargin: 14
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        width: parent.width
                        contentHeight: body.height + 14
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick

                        visible: !root.current.wheel

                        Connections {
                            target: root
                            function onPageChanged() { scroller.contentY = 0 }
                        }

                        NumberAnimation { id: scrollAnim; target: scroller; property: "contentY"; duration: 140; easing.type: Easing.OutCubic }

                        Column {
                            id: body
                            width: scroller.width
                            spacing: 16

                            Repeater {
                                model: root.current.sections

                                Column {
                                    id: sec
                                    required property var modelData
                                    required property int index
                                    visible: root.sectionVisible(modelData, Store.values, Store.caps, Store.waybar)
                                    width: body.width
                                    spacing: 6

                                    // Entrance: each section slides in from the side you came from, one after another.
                                    property real enter: 0
                                    opacity: enter
                                    transform: Translate { x: (1 - sec.enter) * 22 * root.pageDir; y: (1 - sec.enter) * 10 }

                                    SequentialAnimation {
                                        id: enterAnim
                                        PropertyAction { target: sec; property: "enter"; value: 0 }
                                        PauseAnimation { duration: 40 + Math.min(sec.index, 6) * 70 }
                                        NumberAnimation { target: sec; property: "enter"; to: 1; duration: 460; easing.type: Easing.OutCubic }
                                    }
                                    Component.onCompleted: enterAnim.start()
                                    Connections {
                                        target: root
                                        function onEnterSerialChanged() { enterAnim.restart() }
                                    }

                                    Text {
                                        x: 4
                                        text: sec.modelData.label.toUpperCase()
                                        font.family: Theme.sans
                                        font.pixelSize: 10
                                        font.letterSpacing: 1.6
                                        color: Theme.dim
                                    }

                                    Rectangle {
                                        width: sec.width
                                        height: rows.height
                                        radius: 12
                                        color: sec.modelData.controls.length === 1 && sec.modelData.controls[0].type === "action"
                                            ? "transparent" : Theme.alpha(Theme.fg, 0.055)

                                        Column {
                                            id: rows
                                            width: parent.width

                                            Repeater {
                                                model: sec.modelData.controls

                                                Item {
                                                    id: row
                                                    required property var modelData
                                                    required property int index
                                                    readonly property bool on: root.controlShown(modelData, Store.values, Store.caps, Store.waybar)
                                                    readonly property int lead: root.firstShown(sec.modelData.controls, Store.values, Store.caps, Store.waybar)
                                                    // Animating a 0..1 amount (not the height) keeps live resizes, like an expanding dropdown, immediate.
                                                    property real reveal: on ? 1 : 0
                                                    Behavior on reveal { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                                                    // Each control fades up a beat after the one above it.
                                                    property real rowEnter: 0
                                                    SequentialAnimation {
                                                        id: rowAnim
                                                        PropertyAction { target: row; property: "rowEnter"; value: 0 }
                                                        PauseAnimation { duration: 140 + Math.min(sec.index, 6) * 70 + Math.min(row.index, 8) * 45 }
                                                        NumberAnimation { target: row; property: "rowEnter"; to: 1; duration: 420; easing.type: Easing.OutCubic }
                                                    }
                                                    Component.onCompleted: rowAnim.start()
                                                    Connections {
                                                        target: root
                                                        function onEnterSerialChanged() { rowAnim.restart() }
                                                    }
                                                    transform: Translate { y: (1 - row.rowEnter) * 8 }

                                                    width: rows.width
                                                    height: inner.height * reveal
                                                    opacity: reveal * rowEnter
                                                    visible: reveal > 0.001
                                                    clip: reveal < 1 || rowEnter < 1

                                                    Column {
                                                        id: inner
                                                        width: row.width

                                                        Rectangle {
                                                            visible: row.index > row.lead
                                                            x: Theme.pad
                                                            width: parent.width - Theme.pad * 2
                                                            height: 1
                                                            color: Theme.alpha(Theme.fg, 0.07)
                                                        }

                                                        Loader {
                                                            width: row.width
                                                            height: item ? item.implicitHeight : 0
                                                            Component.onCompleted: setSource(root.source(row.modelData.type), { def: row.modelData })
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // The color page is a wheel instead of a list.
                    Loader {
                        id: wheelHost
                        anchors.top: tabs.bottom
                        anchors.topMargin: 6
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        width: parent.width
                        active: root.current.wheel === true
                        source: "ColorWheel.qml"
                        onLoaded: wheelFade.restart()
                        NumberAnimation { id: wheelFade; target: wheelHost; property: "opacity"; from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }
                    }
                }

                // Right edge: drag to resize; pull it far enough back and the sheet snaps closed.
                Item {
                    id: grab
                    anchors.right: parent.right
                    width: 16
                    height: parent.height

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 6
                        width: 4
                        height: grabArea.containsMouse || grabArea.pressed ? 64 : 40
                        radius: 2
                        color: Theme.alpha(grabArea.containsMouse || grabArea.pressed ? Theme.accent : Theme.fg, grabArea.containsMouse || grabArea.pressed ? 0.85 : 0.25)
                        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                    }

                    MouseArea {
                        id: grabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeHorCursor

                        property real startX: 0
                        property real startWidth: 0

                        // The pointer's position in window space is the truth; the card follows it.
                        function windowX(mouse) {
                            return mapToItem(win.contentItem, mouse.x, mouse.y).x
                        }

                        onPressed: mouse => {
                            startX = windowX(mouse)
                            startWidth = card.width
                            root.dragFrac = card.width / root.screenW
                            root.dragging = true
                        }

                        onPositionChanged: mouse => {
                            if (!pressed) return
                            const w = startWidth + (windowX(mouse) - startX)
                            root.dragFrac = Math.max(0.08, Math.min(root.maxFrac, w / root.screenW))
                        }

                        onReleased: {
                            root.dragging = false
                            const f = root.dragFrac
                            if (f < root.minFrac * 0.75) {
                                root.close()
                                return
                            }
                            let next = Math.max(root.minFrac, f)
                            if (Math.abs(next - root.defaultFrac) * root.screenW < 14) next = root.defaultFrac
                            root.frac = next
                            Store.saveUi("wfrac", next)
                        }
                    }
                }
            }
        }
    }
}
