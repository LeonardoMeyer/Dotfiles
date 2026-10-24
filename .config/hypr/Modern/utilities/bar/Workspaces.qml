import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import "../common"

// Everything about workspaces: the bar's dots, the Exposé page its pill grows into, and the full-screen
// overview (Super+Tab). The root is what they draw from: Hyprland's windows, workspaces and monitor geometry,
// kept fresh only while a view is showing (`active`), by refetching on window events and a slow poll.
Item {
    id: ex

    property bool active: false
    // Bumped after every refetch, so anything reading lastIpcObject re-evaluates.
    property int rev: 0

    readonly property string wallpaper: wallFile.text().trim()

    FileView {
        id: wallFile
        path: Quickshell.env("HOME") + "/.cache/wallpaper-picker/current"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    function refresh() {
        Hyprland.refreshToplevels()
        Hyprland.refreshWorkspaces()
        Hyprland.refreshMonitors()
        settle.restart()
    }
    // The refetch lands asynchronously; re-read once it has.
    Timer { id: settle; interval: 60; onTriggered: ex.rev++ }

    onActiveChanged: if (active) refresh()

    readonly property var events: ["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode",
        "windowtitle", "windowtitlev2", "activewindow", "activewindowv2", "fullscreen", "workspace", "workspacev2",
        "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2", "moveworkspace", "moveworkspacev2"]
    Connections {
        target: Hyprland
        enabled: ex.active
        function onRawEvent(event) { if (ex.events.includes(event.name)) debounce.restart() }
    }
    Timer { id: debounce; interval: 80; onTriggered: ex.refresh() }
    Timer { running: ex.active; interval: 1500; repeat: true; onTriggered: ex.refresh() }

    // A monitor's area in layout coordinates: rotated monitors swap sides, scale shrinks both.
    function geometry(mon) {
        rev
        if (!mon) return { x: 0, y: 0, w: 1920, h: 1080 }
        const o = mon.lastIpcObject || {}
        const sc = o.scale || mon.scale || 1
        const turned = (o.transform ?? 0) % 2 === 1
        const w = (turned ? (o.height ?? mon.height) : (o.width ?? mon.width)) / sc
        const h = (turned ? (o.width ?? mon.width) : (o.height ?? mon.height)) / sc
        return { x: o.x ?? mon.x, y: o.y ?? mon.y, w: w, h: h }
    }

    // Windows on a workspace, oldest first so the most recently used is drawn on top.
    function windowsOn(id) {
        rev
        return Hyprland.toplevels.values
            .filter(t => t.workspace && t.workspace.id === id && t.lastIpcObject && t.lastIpcObject.at
                && t.lastIpcObject.mapped !== false && !t.lastIpcObject.hidden)
            .sort((a, b) => (b.lastIpcObject.focusHistoryID ?? 0) - (a.lastIpcObject.focusHistoryID ?? 0))
    }

    // A monitor's workspaces in order, then the next free number for starting a new one.
    function workspacesOn(screenName) {
        rev
        const all = Hyprland.workspaces.values.filter(w => w.id > 0)
        const ids = all.filter(w => w.monitor && w.monitor.name === screenName).map(w => w.id).sort((a, b) => a - b)
        const used = new Set(all.map(w => w.id))
        let next = 1
        while (used.has(next)) next++
        return { ids: ids, next: next }
    }

    function iconFor(cls) {
        const e = DesktopEntries.heuristicLookup(cls || "")
        return Quickshell.iconPath(e && e.icon ? e.icon : (cls || "").toLowerCase(), true)
            || Quickshell.iconPath("application-x-executable", true)
    }

    function appName(cls) {
        const e = DesktopEntries.heuristicLookup(cls || "")
        return e && e.name ? e.name : (cls || "Window")
    }

    function focusWindow(t) {
        const addr = t.lastIpcObject && t.lastIpcObject.address ? t.lastIpcObject.address : "0x" + t.address
        Theme.dispatch("hl.dsp.focus({ window = \"address:" + addr + "\" })", "focuswindow address:" + addr)
    }

    function goTo(id) {
        Theme.dispatch("hl.dsp.focus({ workspace = " + id + " })", "workspace " + id)
    }

    // ---- Dots -------------------------------------------------------------------------------------------------

    // Workspaces 1-5 always, plus any others, the same on every monitor like waybar's: the focused one stretches
    // into a pill that slides along as focus moves, occupied ones are solid, empty ones faint. Click to go
    // there, scroll to step through them.
    component Dots: Row {
        id: dots

        readonly property int activeId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
        readonly property var existing: Hyprland.workspaces.values.filter(w => w.id > 0)
        readonly property var ids: {
            const s = new Set([1, 2, 3, 4, 5])
            for (const w of existing) s.add(w.id)
            return [...s].sort((a, b) => a - b)
        }

        function occupied(id) {
            const w = existing.find(w => w.id === id)
            return !!w && (!w.toplevels || w.toplevels.values.length > 0)
        }

        function go(id) {
            if (id !== activeId) Theme.dispatch("hl.dsp.focus({ workspace = " + id + " })", "workspace " + id)
        }

        spacing: 6

        Repeater {
            model: dots.ids

            Rectangle {
                required property int modelData
                readonly property bool active: modelData === dots.activeId
                readonly property bool full: dots.occupied(modelData)

                anchors.verticalCenter: parent.verticalCenter
                width: active ? 22 : 8
                height: 8
                radius: 4
                color: active ? Theme.accent
                    : full ? (dotArea.containsMouse ? Theme.bright : Theme.fg)
                    : Theme.alpha(Theme.fg, dotArea.containsMouse ? 0.5 : 0.25)
                Behavior on width { NumberAnimation { duration: Theme.move; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                MouseArea {
                    id: dotArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dots.go(parent.modelData)
                }
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => {
                const i = dots.ids.indexOf(dots.activeId)
                const step = e.angleDelta.y > 0 ? -1 : 1
                dots.go(dots.ids[Math.max(0, Math.min(dots.ids.length - 1, (i < 0 ? 0 : i) + step))])
            }
        }
    }

    // ---- Tile -------------------------------------------------------------------------------------------------

    // One workspace in miniature: the monitor's shape over the wallpaper, each window at its real place with a
    // live preview and its app icon. Click a window to focus it, anywhere else to go to the workspace. `big`
    // (the overview) labels every window; the small tiles name a window while it is hovered.
    component Tile: Item {
        id: tile

        property var expose
        property int wsId: 1
        property var monitor: null
        property bool current: false
        // The "new workspace" tile: no windows, a plus instead.
        property bool isNew: false
        property bool big: false
        signal windowPicked(var toplevel)
        signal workspacePicked(int id)

        readonly property var geom: expose.geometry(monitor)
        readonly property real k: width / geom.w
        readonly property var windows: isNew ? [] : expose.windowsOn(wsId)
        readonly property real r: Math.min(Theme.rounding, big ? 14 : 8)

        implicitHeight: width * geom.h / geom.w

        ClippingRectangle {
            id: screen
            anchors.fill: parent
            radius: tile.r
            color: Theme.alpha(Theme.fg, 0.06)
            scale: area.containsMouse && !tile.big ? 1.03 : 1
            Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

            Image {
                anchors.fill: parent
                visible: !tile.isNew && tile.expose.wallpaper !== ""
                source: tile.expose.wallpaper !== "" ? "file://" + tile.expose.wallpaper : ""
                sourceSize.width: 480
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: area.containsMouse ? 0.9 : 0.7
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.workspacePicked(tile.wsId)
            }

            Column {
                anchors.centerIn: parent
                visible: tile.isNew
                spacing: 4
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ""
                    font.family: Theme.sans
                    font.pixelSize: tile.big ? 28 : 16
                    color: area.containsMouse ? Theme.accent : Theme.dim
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: tile.big
                    text: "New workspace"
                    font.family: Theme.sans
                    font.pixelSize: 12
                    color: Theme.dim
                }
            }

            Repeater {
                model: tile.windows

                Item {
                    id: win
                    required property var modelData
                    readonly property var o: modelData.lastIpcObject
                    readonly property bool hot: winArea.containsMouse
                    x: (o.at[0] - tile.geom.x) * tile.k
                    y: (o.at[1] - tile.geom.y) * tile.k
                    width: Math.max(8, o.size[0] * tile.k)
                    height: Math.max(8, o.size[1] * tile.k)

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Math.min(tile.r - 2, 6)
                        color: Theme.alpha(Theme.bg, 0.85)

                        ScreencopyView {
                            id: shot
                            anchors.fill: parent
                            captureSource: win.modelData.wayland
                            live: true
                            constraintSize: Qt.size(Math.ceil(win.width * 2), Math.ceil(win.height * 2))
                        }

                        // The app's icon: centered until the preview arrives, then a small badge.
                        IconImage {
                            readonly property real full: Math.min(48, Math.min(win.width, win.height) * 0.4)
                            implicitSize: shot.hasContent ? Math.min(full, tile.big ? 22 : 14) : full
                            x: shot.hasContent ? 4 : (win.width - implicitSize) / 2
                            y: shot.hasContent ? win.height - implicitSize - 4 : (win.height - implicitSize) / 2
                            visible: implicitSize >= 8
                            source: tile.expose.iconFor(win.o.class)
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Math.min(tile.r - 2, 6)
                        color: "transparent"
                        border.width: win.hot ? 2 : 1
                        border.color: win.hot ? Theme.accent : Theme.alpha(Theme.fg, 0.12)
                        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
                    }

                    Rectangle {
                        visible: tile.big || win.hot
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: tile.big ? 8 : 3
                        width: Math.min(label.implicitWidth + 16, Math.max(40, win.width - 8))
                        height: tile.big ? 24 : 16
                        radius: Math.min(Theme.rounding, height / 2)
                        color: Theme.alpha(Theme.bg, 0.85)
                        Text {
                            id: label
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - 12)
                            text: win.o.title || tile.expose.appName(win.o.class)
                            elide: Text.ElideRight
                            font.family: Theme.sans
                            font.pixelSize: tile.big ? 11 : 9
                            color: Theme.bright
                        }
                    }

                    MouseArea {
                        id: winArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tile.windowPicked(win.modelData)
                    }
                }
            }
        }

        // The accent marks the workspace on screen.
        Rectangle {
            anchors.fill: parent
            scale: screen.scale
            radius: tile.r
            color: "transparent"
            border.width: tile.current ? 2 : 1
            border.color: tile.current ? Theme.accent : Theme.alpha(Theme.fg, area.containsMouse ? 0.25 : 0.1)
            Behavior on border.color { ColorAnimation { duration: Theme.fast } }
        }
    }

    // ---- Page -------------------------------------------------------------------------------------------------

    // The workspaces pill's page: this monitor's workspaces as tiles, as many columns as the card has room for
    // (so it fits a portrait monitor too), and the way into the overview.
    component Page: Column {
        id: page

        property var expose
        property var screen
        signal picked()
        signal overview()

        readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
        readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
        readonly property var spaces: expose.workspacesOn(screen ? screen.name : "")
        readonly property var cells: spaces.ids.concat([-1])
        readonly property real gap: 10
        readonly property int cols: Math.max(1, Math.min(3, cells.length, Math.floor((width + gap) / (150 + gap))))
        readonly property int rows: Math.ceil(cells.length / cols)
        readonly property var geom: expose.geometry(monitor)
        // Wide as the columns allow, and short enough that every row fits under the bar.
        readonly property real tileW: Math.min((width - (cols - 1) * gap) / cols, (420 / rows - 18) * geom.w / geom.h)

        spacing: 12

        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: page.cols
            spacing: page.gap

            Repeater {
                model: page.cells

                Column {
                    id: cell
                    required property int modelData
                    readonly property bool isNew: modelData === -1
                    readonly property int wsId: isNew ? page.spaces.next : modelData
                    readonly property int count: page.expose.windowsOn(wsId).length
                    spacing: 5

                    Tile {
                        width: page.tileW
                        expose: page.expose
                        monitor: page.monitor
                        wsId: cell.wsId
                        isNew: cell.isNew
                        current: cell.wsId === page.activeId
                        onWindowPicked: t => { page.picked(); page.expose.focusWindow(t) }
                        onWorkspacePicked: id => { page.picked(); page.expose.goTo(id) }
                    }
                    Text {
                        x: 2
                        text: cell.isNew ? "New" : cell.wsId + "  ·  " + (cell.count === 0 ? "empty" : cell.count + (cell.count > 1 ? " windows" : " window"))
                        font.family: Theme.sans
                        font.pixelSize: 10
                        color: cell.wsId === page.activeId ? Theme.accent : Theme.dim
                    }
                }
            }
        }

        Menus.Group {
            Menus.Entry {
                glyph: "󰕮"
                label: "Overview"
                trailing: "Super + Tab"
                onClicked: { page.picked(); page.overview() }
            }
        }
    }

    // ---- Overview ---------------------------------------------------------------------------------------------

    // Every workspace on a monitor as a large tile with live, labelled windows, over the blurred desktop. Click a
    // window to focus it, a workspace to go there, the backdrop (or Escape) to close; 1-9 jump to a workspace.
    // The window stays mapped and only takes input while showing, so it never waits on a new surface: it fades
    // in and settles into place the way windows open, and leaves the way they close.
    component Overview: PanelWindow {
        id: ov

        property var expose
        property bool open: false
        signal dismissed()

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overview"
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region { item: ov.open ? backdrop : null }

        // 0 hidden, 1 showing; the tiles only exist (and capture windows) while it is above 0.
        property real t: 0
        readonly property bool shown: open || t > 0
        onOpenChanged: {
            tween.stop()
            tween.to = open ? 1 : 0
            tween.duration = Theme.ms(open ? 400 : 280)
            tween.easing.bezierCurve = open ? Theme.settle : Theme.leave
            tween.start()
            if (open) keys.forceActiveFocus()
        }
        NumberAnimation { id: tween; target: ov; property: "t"; easing.type: Easing.BezierSpline }

        readonly property var monitor: Hyprland.monitorFor(screen)
        readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
        readonly property var spaces: expose ? expose.workspacesOn(screen ? screen.name : "") : ({ ids: [], next: 1 })
        readonly property var tiles: spaces.ids.concat([-1])
        readonly property int cols: tiles.length <= 3 ? tiles.length : tiles.length <= 6 ? 3 : 4
        readonly property real gap: 28
        readonly property int rows: Math.ceil(tiles.length / cols)
        readonly property var geom: expose ? expose.geometry(monitor) : ({ x: 0, y: 0, w: 1920, h: 1080 })
        // As large as fits both ways, so portrait monitors don't run off the screen.
        readonly property real tileW: Math.min(620, (width - 160 - (cols - 1) * gap) / cols,
            (height - 200 - (rows - 1) * (gap + 30)) / rows * geom.w / geom.h)

        function pickWindow(t) {
            expose.focusWindow(t)
            dismissed()
        }

        function pickWorkspace(id) {
            expose.goTo(id)
            dismissed()
        }

        Rectangle {
            id: backdrop
            anchors.fill: parent
            color: Theme.alpha(Theme.bg, 0.55)
            opacity: ov.t
            visible: ov.t > 0
        }

        MouseArea {
            anchors.fill: parent
            onClicked: ov.dismissed()
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) ov.dismissed()
                else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) ov.pickWorkspace(e.key - Qt.Key_0)
                else { e.accepted = false; return }
                e.accepted = true
            }
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: (1 - ov.t) * 24
            spacing: 26
            visible: ov.t > 0
            opacity: ov.t
            scale: 0.96 + 0.04 * ov.t

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Workspaces"
                    font.family: Theme.sans
                    font.pixelSize: 22
                    color: Theme.bright
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (ov.screen ? ov.screen.name + "  ·  " : "") + "click to focus  ·  1-9 to jump  ·  Esc to close"
                    font.family: Theme.sans
                    font.pixelSize: 11
                    color: Theme.dim
                }
            }

            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: ov.cols
                columnSpacing: ov.gap
                rowSpacing: ov.gap

                Repeater {
                    model: ov.shown ? ov.tiles : []

                    Column {
                        id: cell
                        required property int modelData
                        required property int index
                        readonly property bool isNew: modelData === -1
                        readonly property int wsId: isNew ? ov.spaces.next : modelData
                        readonly property var windows: ov.expose.windowsOn(wsId)
                        spacing: 10
                        // Tiles settle in one after another.
                        opacity: Math.max(0, Math.min(1, ov.t * 1.6 - index * 0.06))

                        Row {
                            spacing: 8
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: cell.isNew ? "New" : cell.wsId
                                font.family: Theme.sans
                                font.pixelSize: 15
                                font.bold: true
                                color: cell.wsId === ov.activeId ? Theme.accent : Theme.bright
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, ov.tileW - 40)
                                elide: Text.ElideRight
                                text: cell.isNew ? "Start a fresh workspace"
                                    : cell.windows.length === 0 ? "Empty"
                                    : [...new Set(cell.windows.map(w => ov.expose.appName(w.lastIpcObject.class)))].join("  ·  ")
                                font.family: Theme.sans
                                font.pixelSize: 11
                                color: Theme.dim
                            }
                        }

                        Tile {
                            width: ov.tileW
                            big: true
                            expose: ov.expose
                            monitor: ov.monitor
                            wsId: cell.wsId
                            isNew: cell.isNew
                            current: cell.wsId === ov.activeId
                            onWindowPicked: t => ov.pickWindow(t)
                            onWorkspacePicked: id => ov.pickWorkspace(id)
                        }
                    }
                }
            }
        }
    }
}
