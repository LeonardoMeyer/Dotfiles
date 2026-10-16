import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "Schema.js" as Schema

// Hyprland settings sheet: slides up from the bottom edge, toggled with Alt+S (see settings.sh).
// The top edge drags to resize; the height is remembered between sessions.
ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property real defaultFrac: 1 / 3
    readonly property real minFrac: 0.22
    readonly property real maxFrac: 0.9

    // Resident and hidden; show() and close() drive each appearance.
    property bool active: false
    property bool leaving: false
    property real t: 0
    property var targetScreen: null

    property real frac: defaultFrac
    property real dragFrac: defaultFrac
    property bool dragging: false
    property string page: "profile"
    readonly property var current: Schema.PAGES.find(p => p.id === page) || Schema.PAGES[0]

    FileView {
        id: uiFile
        path: root.home + "/.local/state/hypr-settings/ui.json"
        blockLoading: true
    }

    Component.onCompleted: {
        try {
            const ui = JSON.parse(uiFile.text())
            if (typeof ui.frac === "number") frac = Math.max(minFrac, Math.min(maxFrac, ui.frac))
            if (ui.page && Schema.PAGES.some(p => p.id === ui.page)) page = ui.page
        } catch (e) {}
        dragFrac = frac
        Store.refresh()
    }

    function show() {
        if (active && !leaving) return
        const mon = Hyprland.focusedMonitor
        targetScreen = Quickshell.screens.find(s => s.name === mon?.name) ?? Quickshell.screens[0]
        Store.refresh()
        leaving = false
        if (!active) {
            active = true
            t = 0
        }
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

    function selectPage(id) {
        page = id
        Store.saveUi("page", id)
    }

    // Same curves and timings as style.lua: "fluid" at 300ms in, "snappy" at 250ms out.
    function animateTo(target) {
        tween.stop()
        tween.from = t
        tween.to = target
        tween.duration = target === 1 ? 300 : 250
        tween.easing.type = Easing.BezierSpline
        tween.easing.bezierCurve = target === 1 ? [0.15, 0.85, 0.25, 1, 1, 1] : [0.3, 1, 0.4, 1, 1, 1]
        tween.start()
    }

    NumberAnimation {
        id: tween
        target: root
        property: "t"
        onFinished: if (root.leaving) { root.active = false; root.leaving = false; root.t = 0 }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.close() }
    }

    PanelWindow {
        id: win
        visible: root.active
        screen: root.targetScreen ?? Quickshell.screens[0]
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: card }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "settings-panel"
        WlrLayershell.keyboardFocus: root.active && !root.leaving ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.close()

            Item {
                id: card
                width: parent.width
                height: Math.round(win.height * (root.dragging ? root.dragFrac : root.frac))
                y: parent.height - height + (1 - root.t) * height
                opacity: root.t * (root.dragging && root.dragFrac < root.minFrac * 0.75 ? 0.6 : 1)

                // Matches Hyprland: 10px rounding, no border, translucent background over compositor blur.
                // Square at the bottom: the sheet is attached to the screen edge.
                Rectangle {
                    anchors.fill: parent
                    anchors.bottomMargin: -12
                    radius: 10
                    color: Theme.alpha(Theme.bg, 0.62)
                }

                Item {
                    id: grab
                    width: parent.width
                    height: 22

                    Rectangle {
                        anchors.centerIn: parent
                        width: grabArea.containsMouse || grabArea.pressed ? 56 : 40
                        height: 4
                        radius: 2
                        color: Theme.alpha(grabArea.containsMouse || grabArea.pressed ? Theme.accent : Theme.fg, grabArea.containsMouse || grabArea.pressed ? 0.8 : 0.25)
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }

                    MouseArea {
                        id: grabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeVerCursor

                        property real startY: 0
                        property real startHeight: 0

                        // The pointer's position in window space is the truth; the card follows it.
                        function windowY(mouse) {
                            return mapToItem(win.contentItem, mouse.x, mouse.y).y
                        }

                        onPressed: mouse => {
                            startY = windowY(mouse)
                            startHeight = card.height
                            root.dragFrac = card.height / win.height
                            root.dragging = true
                        }

                        onPositionChanged: mouse => {
                            if (!pressed) return
                            const h = startHeight - (windowY(mouse) - startY)
                            root.dragFrac = Math.max(0.1, Math.min(root.maxFrac, h / win.height))
                        }

                        onReleased: {
                            root.dragging = false
                            const f = root.dragFrac
                            // Pulled well past the minimum: snap down to the bottom edge and close.
                            if (f < root.minFrac * 0.75) {
                                root.close()
                                return
                            }
                            let next = Math.max(root.minFrac, f)
                            if (Math.abs(next - root.defaultFrac) * win.height < 14) next = root.defaultFrac
                            root.frac = next
                            Store.saveUi("frac", next)
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.topMargin: grab.height
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.bottomMargin: 14

                    Flickable {
                        id: railScroll
                        width: 168
                        height: parent.height
                        contentHeight: rail.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: rail
                            width: parent.width
                            spacing: 2

                            Repeater {
                                model: Schema.PAGES
                                RailItem {
                                    required property var modelData
                                    width: rail.width
                                    icon: modelData.icon
                                    text: modelData.label
                                    active: root.page === modelData.id
                                    onClicked: root.selectPage(modelData.id)
                                }
                            }
                        }
                    }

                    Flickable {
                        id: scroller
                        anchors.left: railScroll.right
                        anchors.leftMargin: 20
                        anchors.right: parent.right
                        height: parent.height
                        contentHeight: flow.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        opacity: 1

                        Connections {
                            target: root
                            function onPageChanged() {
                                scroller.contentY = 0
                                pageFade.restart()
                            }
                        }

                        NumberAnimation {
                            id: pageFade
                            target: scroller
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 200
                            easing.type: Easing.OutCubic
                        }

                        Flow {
                            id: flow
                            width: scroller.width - 12
                            spacing: 14

                            readonly property real minCell: 290
                            readonly property int cols: Math.max(1, Math.floor((width + spacing) / (minCell + spacing)))
                            readonly property real cell: (width - spacing * (cols - 1)) / cols

                            Repeater {
                                model: root.current.controls

                                Loader {
                                    required property var modelData
                                    width: Schema.WIDE[modelData.type] ? flow.width : flow.cell
                                    height: item ? item.implicitHeight : 0
                                    Component.onCompleted: setSource(
                                        "Setting" + modelData.type.charAt(0).toUpperCase() + modelData.type.slice(1) + ".qml",
                                        { def: modelData })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
