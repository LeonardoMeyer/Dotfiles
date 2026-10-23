import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../common"

ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property var all: []
    property var items: []
    property var themes: ["all"]
    property string theme: "all"
    property int cur: 0
    property real pos: 0
    // The shell stays resident and hidden; show() and close() drive each open.
    property bool shown: false
    property bool leaving: false
    property real t: 0
    property string indexText: ""
    property var targetScreen: null
    property bool locating: false
    // Chosen wallpaper until wallpaper-apply.sh has written it to the cache.
    property string pendingPath: ""
    // The preview stays up after applying until awww has drawn the same image under it.
    property bool holding: false
    // Each monitor's workspace when the picker opened; they all switch to empty ones so the preview shows.
    property var prevWs: null
    // The full-screen preview follows the selection at once, from its screen-sized copy (wallpaper-index.py), which
    // decodes in a few milliseconds; the original only if the index has none yet.
    property var previewed: null
    readonly property string previewSrc: previewed ? "file://" + (previewed.screen || previewed.path) : ""
    // The blur behind the panel and the preview under it change together: each waits until the other's new image
    // is decoded too (the picker monitor's preview reports here).
    property bool previewReady: true

    // Hyprland's live rounding (override or profile default) for the wallpaper cards.

    // The panel's height and the soft edge its shade fades in over, in stage units.
    readonly property real panelH: 540
    readonly property real fadeH: 320

    // The stage lays out in a fixed 1600x900 space and is scaled to the screen; portrait fits 1100 units across instead.
    readonly property real u: unitFor(win.screen)

    function unitFor(s) {
        if (!s) return 1
        const v = s.height > s.width
            ? Math.min(s.width / 1100, s.height / 1000)
            : Math.min(s.width / 1600, s.height / 900)
        return Math.max(0.5, v)
    }
    // The bars' colours wait for scrolling to pause, so flicking past never rewrites them for each one.
    onCurrentChanged: { previewed = current; previewTimer.restart() }
    Timer {
        id: previewTimer
        interval: 120
        onTriggered: if (root.shown && !root.leaving && root.current) root.tint(root.current.colors)
    }

    // Both bars take the selection's colors while it is shown: the quickshell bar through Theme, waybar through
    // the colors file its style imports. Waybar only watches style.css itself, so its bytes are rewritten in
    // place (never truncated) to make it reload. Only with pywal colors, which follow the wallpaper.
    FileView { id: colorTheme; path: root.home + "/.config/hypr/.color-theme"; blockLoading: true; printErrors: false }
    FileView { id: activeBar; path: root.home + "/.config/hypr/.active-bar"; blockLoading: true; printErrors: false }
    property bool tinted: false

    // Null puts the saved palette back.
    function tint(p) {
        if (!["", "pywal"].includes(colorTheme.text().trim()) || (!p && !tinted)) return
        Theme.preview = p
        tinted = !!p
        if (!Theme.saved) return
        const c = p ?? Array.from({ length: 16 }, (_, i) => Theme.saved.colors["color" + i])
        waybar(["foreground " + c[15], "background " + c[0], "cursor " + c[15], ""]
            .concat(c.map((x, i) => "color" + i + " " + x))
            .map(l => l ? "@define-color " + l + ";" : "").join("\n") + "\n")
    }

    // Writes waybar's colors (or keeps wal's, given nothing) and has it reload them; skipped while it isn't the bar.
    function waybar(css) {
        if (activeBar.text().trim() === "quickshell") return
        Quickshell.execDetached(["sh", "-c", '[ -z "$0" ] || printf %s "$0" > ~/.cache/wal/colors-waybar.css; s=~/.config/waybar/style.css; dd if="$s" of="$s" conv=notrunc status=none', css])
    }
    readonly property var current: items.length > 0 ? items[Math.max(0, Math.min(cur, items.length - 1))] : null
    readonly property var palette: current ? current.colors : []
    // Darkest to lightest so the strip blends smoothly.
    readonly property var ramp: palette.length === 16
        ? palette.slice().sort((a, b) => lum(a) - lum(b))
        : []

    function lum(c) {
        const q = Qt.color(c)
        return 0.2126 * q.r + 0.7152 * q.g + 0.0722 * q.b
    }

    Behavior on pos { id: posBehavior; NumberAnimation { duration: Theme.ms(380); easing.type: Easing.OutCubic } }

    // Last applied wallpaper; read synchronously so the open never jumps mid-animation.
    FileView {
        id: curFile
        path: root.home + "/.cache/wallpaper-picker/current"
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property string applied: curFile.text().trim()
    readonly property string landing: pendingPath !== "" ? pendingPath : applied

    // Re-centres while hidden so the next open finds the wheel already positioned and its thumbnails decoded.
    onAppliedChanged: {
        // wal has written the real palette by now (wallpaper-apply.sh records the wallpaper last).
        if (applied === pendingPath) { pendingPath = ""; holding = false; Theme.preview = null; tinted = false; waybar("") }
        if (!shown) rebuild(landing)
    }

    function seg(delay) {
        return Math.max(0, Math.min(1, (t - delay) / (1 - delay)))
    }

    function jump(i) {
        posBehavior.enabled = false
        cur = i
        pos = i
        posBehavior.enabled = true
    }

    // Reuses the existing item list when unchanged so opening never rebuilds the carousel.
    function rebuild(path) {
        const list = theme === "all" ? all : all.filter(w => w.theme === theme)
        if (items !== list) items = list
        const i = path ? list.findIndex(w => w.path === path) : -1
        jump(Math.max(0, i))
    }

    function go(i) {
        if (items.length === 0) return
        cur = Math.max(0, Math.min(items.length - 1, i))
        pos = cur
    }

    function nextTheme(step) {
        const i = themes.indexOf(theme)
        theme = themes[(i + step + themes.length) % themes.length]
        rebuild()
    }

    function apply() {
        if (!current || leaving) return
        pendingPath = current.path
        holding = current.path !== applied
        holdTimer.restart()
        Quickshell.execDetached([home + "/.config/hypr/utilities/wallpaper-apply.sh", current.path])
        close()
    }

    function show() {
        Theme.refresh()
        watchdog.stop()
        if ((shown && !leaving) || locating) return
        // Re-read each open: the bar or color scheme may have changed since (written by rename, which watches miss).
        activeBar.reload()
        colorTheme.reload()
        locating = true
        Theme.locate(open)
    }

    function open(screen) {
        locating = false
        if (shown && !leaving) return
        leaving = false
        t = 0
        if (!current || current.path !== landing) rebuild(landing)
        // Frozen for this open so moving the cursor to another monitor never drags the window along.
        targetScreen = screen
        previewed = current
        wsQuery.running = true
        shown = true
        startTimer.restart()
        Qt.callLater(() => stage.forceActiveFocus())
    }

    function toggle() {
        if (shown && !leaving) close()
        else show()
    }

    // Unmapping (rather than exiting) hands focus and the pointer straight back to the desktop.
    function finish() {
        restoreWorkspace()
        watchdog.stop()
        startTimer.stop()
        tween.stop()
        shown = false
        leaving = false
        t = 0
        if (theme !== "all") theme = "all"
        rebuild(landing)
    }

    // Asked of Hyprland directly: Quickshell's view of each monitor's workspace can lag behind.
    Process {
        id: wsQuery
        command: ["sh", "-c", "hyprctl -j monitors | tr -d '\\n'; echo; hyprctl -j workspaces | tr -d '\\n'"]
        stdout: StdioCollector { onStreamFinished: root.clearScreens(text) }
    }

    // Monitors showing windows move to empty workspaces so the preview shows, each to the lowest number not in
    // use (made on the focused monitor; Hyprland's "emptym" can pick an empty one on the other monitor instead).
    // An empty one stays: it is already clear, and leaving it would have Hyprland delete it. The picker's own
    // monitor goes last, so focus ends there.
    function clearScreens(text) {
        let mons, wss
        try { [mons, wss] = text.trim().split("\n").map(l => JSON.parse(l)) } catch (e) { return }
        if (!shown || leaving) return
        const main = win.screen.name
        const windows = id => (wss.find(w => w.id === id) || {}).windows || 0
        const busy = mons.filter(m => windows(m.activeWorkspace.id) > 0)
            .sort((a, b) => (a.name === main) - (b.name === main))
        const used = wss.map(w => w.id)
        let free = 0
        prevWs = busy.map(m => [m.name, m.activeWorkspace.id])
        if (busy.length > 0)
            hypr(busy.reduce((l, m) => {
                while (used.includes(++free));
                return l.concat([focusMonitor(m.name), "hl.dsp.focus({ workspace = " + free + " })"])
            }, []).concat([focusMonitor(main)]))
    }

    // Back in the same order, ending on the picker's monitor.
    function restoreWorkspace() {
        if (prevWs && prevWs.length > 0)
            hypr(prevWs.reduce((l, [m, id]) => l.concat([focusMonitor(m), "hl.dsp.focus({ workspace = " + id + " })"]), [])
                .concat([focusMonitor(win.screen.name)]))
        prevWs = null
    }

    function focusMonitor(name) {
        return 'hl.dsp.focus({ monitor = "' + name + '" })'
    }

    // Runs Hyprland dispatches in order, in one call. Focusing a monitor warps the cursor to it, so it goes back after.
    function hypr(cmds) {
        Quickshell.execDetached(["sh", "-c", 'set -- "$0" $(hyprctl cursorpos | tr -d ,); hyprctl --batch "$1 ; dispatch hl.dsp.cursor.move({ x = $2, y = $3 })"',
                                 cmds.map(c => "dispatch " + c).join(" ; ")])
    }

    // A failed apply never leaves the preview covering the desktop.
    Timer { id: holdTimer; interval: 8000; onTriggered: { root.holding = false; root.tint(null) } }

    // Last resort: a stalled close must never leave the full-screen surface grabbing input.
    Timer { id: watchdog; interval: Theme.ms(1200) + 100; onTriggered: root.finish() }

    function animateTo(target) {
        tween.stop()
        tween.from = t
        tween.to = target
        tween.duration = Theme.ms(target === 1 ? 900 : 380)
        // A gentle close, so the preview dissolves back into the current wallpaper rather than blinking out.
        tween.easing.type = target === 1 ? Easing.OutCubic : Easing.InOutSine
        tween.start()
    }

    function tryStart() {
        if (shown && !leaving && !tween.running && t === 0) animateTo(1)
    }

    function close() {
        if (!shown || leaving) return
        leaving = true
        restoreWorkspace()
        previewTimer.stop()
        if (!holding) tint(null)
        startTimer.stop()
        watchdog.restart()
        if (t < 0.001) finish()
        else animateTo(0)
    }

    // One value drives the whole entrance and exit; Hyprland's own layer animation is off for this namespace.
    NumberAnimation {
        id: tween
        target: root
        property: "t"
        onFinished: {
            if (root.leaving) root.finish()
            // Indexing is deferred so its CPU use never competes with the entrance.
            else if (root.t >= 1) indexer.running = true
        }
    }
    // One frame at t=0 is drawn first so the fade never skips.
    Timer { id: startTimer; interval: 30; onTriggered: root.tryStart() }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.close() }
    }

    // Picks up newly added wallpapers; serialized so overlapping runs never read a half-written index.
    Process {
        id: indexer
        running: true
        command: ["flock", "-w", "5", (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/wallpaper-index.lock",
                  "python3", root.home + "/.config/hypr/utilities/wallpaper-index.py"]
        onExited: { idx.running = true; if (reindex.again) { reindex.again = false; running = true } }
    }

    // New wallpapers are indexed as they land: the library and each theme folder in it are watched, and a change
    // runs the indexer once things settle (again after it, if it was already running).
    readonly property string library: home + "/wallpapers/library"
    Variants {
        model: [""].concat(root.themes.slice(1))
        delegate: FolderListModel {
            required property string modelData
            folder: "file://" + root.library + (modelData ? "/" + modelData : "")
            showDirs: !modelData
            showFiles: !!modelData
            onCountChanged: reindex.restart()
        }
    }
    Timer {
        id: reindex
        property bool again: false
        interval: 400
        onTriggered: { if (indexer.running) again = true; else indexer.running = true }
    }

    Process {
        id: idx
        command: ["cat", root.home + "/.cache/wallpaper-picker/index.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === root.indexText) return
                let parsed
                try {
                    parsed = JSON.parse(text)
                } catch (e) {
                    parsed = []
                }
                root.indexText = text
                root.all = parsed
                if (parsed.length === 0) {
                    root.close()
                    return
                }
                const seen = {}
                root.all.forEach(w => seen[w.theme] = true)
                root.themes = ["all"].concat(Object.keys(seen).sort())
                root.rebuild(root.shown && root.current ? root.current.path : root.landing)
            }
        }
    }

    // A new image only fades in once decoded, so quick flips never show a blank frame.
    component CrossImage: Item {
        id: ci
        property string src: ""
        property var front: imgA
        readonly property var back: front === imgA ? imgB : imgA
        // Holds a decoded image back instead of fading it in, so two of these can change in the same frame.
        property bool hold: false
        // The new image is decoded: showing, or waiting to.
        readonly property bool ready: src === "" || [front, back].some(i => i.status === Image.Ready && i.source.toString() === src)
        property int zTop: 0

        function promote(img) {
            img.z = ++zTop
            img.opacity = 0
            fade.target = img
            fade.restart()
            front = img
        }

        // A change during a fade waits for it to finish (the image under it is still showing), so the picture
        // never jumps mid-blend.
        // Emptied, it lets its images go (while hidden, the real wallpaper underneath is the same picture).
        onSrcChanged: {
            if (src === "") { fade.stop(); imgA.source = ""; imgB.source = "" }
            else if (!fade.running) load()
        }
        // Deferred to the end of the update that released it (still before the next frame), so every image
        // waiting on the same release swaps together without re-entering it.
        onHoldChanged: Qt.callLater(tryPromote)
        function load() {
            if (back.source.toString() === src) tryPromote()
            else back.source = src
        }
        function tryPromote() {
            const b = back
            if (!hold && !fade.running && b.status === Image.Ready && b.source.toString() === src) promote(b)
        }

        // The image faded out is let go, so each screen holds one decoded wallpaper.
        NumberAnimation {
            id: fade
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.ms(300)
            easing.type: Easing.InOutSine
            onFinished: { ci.back.source = ""; if (ci.src !== "" && ci.front.source.toString() !== ci.src) ci.load() }
        }

        Image {
            id: imgA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            onStatusChanged: if (ci.back === imgA) ci.tryPromote()
        }
        Image {
            id: imgB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: 0
            onStatusChanged: if (ci.back === imgB) ci.tryPromote()
        }
    }

    // A chip's colour easing along with the wallpaper's crossfade, and its name.
    component Tint: ColorAnimation { duration: Theme.ms(300); easing.type: Easing.InOutSine }
    component Label: Text {
        anchors.centerIn: parent
        font.family: Theme.sans
        font.pixelSize: Math.round(14 * root.u)
    }

    // One pass of the backdrop's blur (blur.frag), rendered small and drawn smoothly scaled up.
    component Pass: ShaderEffect {
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: area.res
        property real start: 1 - win.height / area.height
        property real span: root.fadeH * root.u / area.height
        property real radius: 24
        property real fade: 0
        fragmentShader: Qt.resolvedUrl("blur.frag.qsb")
    }

    // A chip's shape, drawn like the old selector's cards and glass pane: into a texture at twice its size with a
    // margin of clear pixels, then mipmapped down, so the curve comes out even; and a thin white border laid over
    // the fill rather than around it, so there is one clean edge (which also gives the glass a defined rim).
    component Pill: Item {
        property color fill
        property color edge
        property real radius
        anchors.fill: parent
        anchors.margins: -2
        layer.enabled: true
        layer.smooth: true
        layer.mipmap: true
        layer.textureSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: parent.radius
            color: parent.fill
            Behavior on color { Tint {} }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: parent.edge
        }
    }

    // The theme chips, each on a card like the other utilities' backgrounds with a white name; the selected one is
    // the reverse, accent behind dark text. The highlight stretches between them, its leading edge ahead of its
    // trailing one, and every colour eases along with the wallpaper's crossfade. Drawn on the glass layer when
    // hyprglass is on (tabGlass), otherwise in the picker, which always keeps a copy for the clicks. Laid out in
    // whole screen pixels rather than the stage's scaled units, so every edge lands on a pixel and cuts clean.
    component ChipRow: Item {
        id: row
        property bool drawn: true
        property Item sel: null
        // The first placement after (re)building the chips lands without sliding in from the left.
        property bool settled: false
        readonly property int h: Math.round(36 * root.u)
        readonly property int pad: Math.round(36 * root.u)
        readonly property real radius: Math.min(h / 2, Theme.rounding)
        readonly property int lead: Theme.ms(260)
        readonly property int trail: Theme.ms(420)

        x: Math.round((parent.width - width) / 2)
        y: Math.round(110 * root.u)
        width: chips.width
        height: chips.height
        opacity: Math.max(0.001, root.seg(0))
        transform: Translate { y: (1 - root.seg(0)) * 40 * root.u }

        Row {
            id: chips
            spacing: Math.round(8 * root.u)
            Repeater {
                model: root.themes
                onItemAdded: { row.settled = false; settleChips.restart() }
                delegate: Item {
                    id: chip
                    required property string modelData
                    readonly property bool active: root.theme === modelData
                    onActiveChanged: if (active) row.sel = chip
                    Component.onCompleted: if (active) row.sel = chip
                    width: Math.round(label.implicitWidth) + row.pad
                    height: row.h
                    Pill { visible: row.drawn; radius: row.radius; fill: Theme.alpha(Theme.bg, 0.6); edge: "#40ffffff" }
                    Label { id: label; visible: row.drawn; text: chip.modelData; color: "#ffffff" }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root.theme = chip.modelData; root.rebuild() }
                    }
                }
            }
        }
        Timer { id: settleChips; interval: 50; onTriggered: row.settled = true }

        // Over the chips, gliding between them.
        Item {
            id: highlight
            visible: row.drawn && !!row.sel
            property real l: row.sel ? row.sel.x : 0
            property real r: row.sel ? row.sel.x + row.sel.width : 0
            Behavior on l { id: lb; enabled: row.settled; NumberAnimation { duration: lb.targetValue > highlight.l ? row.trail : row.lead; easing.type: Easing.OutCubic } }
            Behavior on r { id: rb; enabled: row.settled; NumberAnimation { duration: rb.targetValue > highlight.r ? row.lead : row.trail; easing.type: Easing.OutCubic } }
            x: l
            width: r - l
            height: row.h

            Pill { radius: row.radius; fill: Theme.accent; edge: "#66ffffff" }

            // The names again in the dark colour, clipped to the highlight, so each turns dark where it passes.
            Item {
                anchors.fill: parent
                clip: true
                Row {
                    x: -highlight.x
                    spacing: chips.spacing
                    Repeater {
                        model: root.themes
                        Item {
                            required property string modelData
                            width: Math.round(dark.implicitWidth) + row.pad
                            height: row.h
                            Label {
                                id: dark
                                text: parent.modelData
                                color: Theme.bg
                                Behavior on color { Tint {} }
                            }
                        }
                    }
                }
            }
        }
    }

    // The selected wallpaper, full screen and sharp on every monitor, under the windows and the bar: a live preview
    // over the real wallpaper. After applying it stays until awww has drawn the same image beneath it. Empty while
    // hidden, so opening never flashes an image left from before (the wallpaper beneath shows until it loads).
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.shown || root.holding
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "wallpaper-picker-preview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            CrossImage {
                id: shot
                anchors.fill: parent
                src: root.shown || root.holding ? root.previewSrc : ""
                hold: modelData === win.screen && !backdrop.ready
                // Fades with the panel, so closing without applying dissolves back into the current wallpaper beneath.
                opacity: root.holding ? 1 : root.t
            }
            Binding { target: root; property: "previewReady"; value: shot.ready; when: modelData === win.screen }
            // The desktop above the panel closes it, like clicking outside any other utility.
            MouseArea { anchors.fill: parent; onClicked: root.close() }
        }
    }

    // The chips' glass. hyprglass glasses whole layers by their alpha (wallpaper-picker-tab in hyprglass.lua), so
    // with it on they are drawn on a layer of their own over the picker, the panel's size. It maps once the
    // picker has, so it stacks above it, and takes no input: the picker's own copy underneath gets the clicks.
    PanelWindow {
        id: tabGlass
        visible: root.shown && Theme.glass && root.t > 0
        screen: win.screen
        anchors { bottom: true; left: true; right: true }
        implicitHeight: win.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wallpaper-picker-tab"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        ChipRow {}
    }

    // The picker: a panel along the bottom that leaves the bar uncovered.
    PanelWindow {
        id: win
        visible: root.shown
        screen: root.targetScreen ?? Quickshell.screens[0]
        anchors { bottom: true; left: true; right: true }
        implicitHeight: Math.ceil(root.panelH * root.u)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wallpaper-picker"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // Backdrop: the selection's thumbnail laid out full screen, so it lines up with the preview behind, under one
        // progressive blur (blur.frag): its radius grows smoothly from nothing at the panel's top edge, fading in from
        // clear as it starts, so there is no edge anywhere and no sharp image showing through a soft one. Run at a
        // third of the screen's resolution, and only redrawn when the picture changes. Hazed with pywal's
        // background. Never 0 opacity: Qt skips invisible items, which would defer their first render.
        Item {
            id: area
            width: parent.width
            height: win.screen ? win.screen.height : parent.height
            y: parent.height - height
            opacity: Math.max(0.001, root.t)
            readonly property size res: Qt.size(Math.ceil(width / 3), Math.ceil(height / 3))

            CrossImage {
                id: backdrop
                anchors.fill: parent
                src: root.previewed ? "file://" + root.previewed.thumb : ""
                hold: !root.previewReady
                visible: false
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: area.res
            }

            Pass {
                id: across
                visible: false
                property var source: backdrop
                property vector2d texel: Qt.vector2d(1 / area.res.width, 0)
            }
            Pass {
                property var source: across
                property vector2d texel: Qt.vector2d(0, 1 / area.res.height)
                fade: 1
            }

            Rectangle {
                id: haze
                anchors.fill: parent
                readonly property real a: 1 - win.height / height
                readonly property real d: root.fadeH * root.u / height
                gradient: Gradient {
                    GradientStop { position: haze.a; color: Theme.alpha(Theme.bg, 0) }
                    GradientStop { position: haze.a + haze.d / 3; color: Theme.alpha(Theme.bg, 0.07) }
                    GradientStop { position: haze.a + haze.d * 2 / 3; color: Theme.alpha(Theme.bg, 0.25) }
                    GradientStop { position: haze.a + haze.d; color: Theme.alpha(Theme.bg, 0.35) }
                    GradientStop { position: 1; color: Theme.alpha(Theme.bg, 0.45) }
                }
            }
        }

        Item {
            id: stage
            width: parent.width / root.u
            height: parent.height / root.u
            scale: root.u
            transformOrigin: Item.TopLeft
            focus: true

            Keys.onPressed: event => {
                const k = event.key
                if (k === Qt.Key_Escape) root.close()
                else if (k === Qt.Key_Right || k === Qt.Key_L) root.go(root.cur + 1)
                else if (k === Qt.Key_Left || k === Qt.Key_H) root.go(root.cur - 1)
                else if (k === Qt.Key_Home) root.go(0)
                else if (k === Qt.Key_End) root.go(root.items.length - 1)
                else if (k === Qt.Key_PageDown) root.go(root.cur + 5)
                else if (k === Qt.Key_PageUp) root.go(root.cur - 5)
                else if (k === Qt.Key_Tab || k === Qt.Key_Down || k === Qt.Key_J) root.nextTheme(1)
                else if (k === Qt.Key_Backtab || k === Qt.Key_Up || k === Qt.Key_K) root.nextTheme(-1)
                else if (k === Qt.Key_R) root.go(Math.floor(Math.random() * root.items.length))
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.apply()
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
                onWheel: wheel => root.go(root.cur + (wheel.angleDelta.y + wheel.angleDelta.x < 0 ? 1 : -1))
            }

            // The wallpapers in a row, on a shallow curve: each turns a few degrees more the further out it sits.
            Item {
                id: wheel
                anchors.left: parent.left
                anchors.right: parent.right
                // Below the chips (drawn over the stage, in screen pixels: 110 down, 36 tall).
                anchors.top: parent.top
                anchors.topMargin: 180
                height: 250
                opacity: Math.max(0.001, root.seg(0.08))
                transform: Translate { y: (1 - root.seg(0.08)) * 60 }

                readonly property real cardW: 400
                readonly property real cardH: 225
                readonly property real step: cardW + 28
                // Cards past the screen's edge are skipped; a few more stay loaded so they are decoded on arrival.
                readonly property real reach: width / 2 / step + 1

                Repeater {
                    model: root.items
                    delegate: Item {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property real d: index - root.pos
                        readonly property real ad: Math.abs(d)

                        visible: ad < wheel.reach
                        width: wheel.cardW
                        height: wheel.cardH
                        y: (wheel.height - height) / 2
                        x: (wheel.width - width) / 2 + d * wheel.step
                        z: 100 - ad * 10
                        scale: 1 - 0.08 * Math.min(ad, 1)

                        transform: Rotation {
                            origin.x: card.width / 2
                            origin.y: card.height / 2
                            axis { x: 0; y: 1; z: 0 }
                            angle: -Math.max(-2.5, Math.min(2.5, card.d)) * 6
                        }

                        Loader {
                            anchors.fill: parent
                            active: card.ad < wheel.reach + 3
                            sourceComponent: frame
                        }

                        Component {
                            id: frame
                            // Drawn once into a texture at twice the size it lands on screen (the stage is scaled by u)
                            // and mipmapped, so scaling it down evens out the thin border on the curves and the turned
                            // cards stay clean. The margin of empty pixels around it means the edge that turns in 3D is
                            // the border's own smooth edge, never the texture's hard one.
                            Item {
                                readonly property real k: 2 * root.u * (win.devicePixelRatio || 1)
                                // The stage is scaled by u, so this undoes it to land on Hyprland's own pixels.
                                readonly property real radius: Theme.rounding / root.u
                                anchors.fill: parent
                                anchors.margins: -2
                                layer.enabled: true
                                layer.smooth: true
                                layer.mipmap: true
                                layer.textureSize: Qt.size(Math.ceil(width * k), Math.ceil(height * k))

                                ClippingRectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: parent.radius
                                    color: "#22000000"

                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + card.modelData.thumb
                                        sourceSize.width: 640
                                        sourceSize.height: 360
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        opacity: status === Image.Ready ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: Theme.ms(300) } }
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        gradient: Gradient {
                                            GradientStop { position: 0; color: "#30ffffff" }
                                            GradientStop { position: 0.45; color: "#00ffffff" }
                                        }
                                    }
                                }

                                // Over the image rather than around it, so there is one edge and no seam between two.
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: parent.radius
                                    color: "transparent"
                                    border.width: 1.5 / root.u
                                    border.color: card.ad < 0.5 ? "#80ffffff" : "#40ffffff"
                                    Behavior on border.color { ColorAnimation { duration: Theme.ms(250) } }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: card.index === root.cur ? root.apply() : root.go(card.index)
                        }
                    }
                }
            }

            // Name and palette of the focused wallpaper.
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: wheel.bottom
                anchors.topMargin: 18
                spacing: 14
                opacity: Math.max(0.001, root.seg(0.22))
                transform: Translate { y: (1 - root.seg(0.22)) * 40 }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.current ? root.current.name.replace(/[_-]/g, " ") : ""
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 700)
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.sans
                    font.pixelSize: 18
                    color: "#ffffff"
                }

                // Its 16 colors side by side in one skinny bar, rounded like Hyprland's windows. On a switch they
                // change in a wave from left to right, with a glint riding along it.
                ClippingRectangle {
                    id: strip
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 520
                    height: 10
                    radius: Math.min(height / 2, Theme.rounding / root.u)
                    color: "#22ffffff"

                    Row {
                        Repeater {
                            model: 16
                            Rectangle {
                                required property int index
                                width: strip.width / 16
                                height: strip.height
                                color: root.ramp[index] ?? "transparent"
                                Behavior on color {
                                    SequentialAnimation {
                                        PauseAnimation { duration: Theme.ms(index * 16) }
                                        ColorAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: glint
                        width: 90
                        height: strip.height
                        x: -width
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#00ffffff" }
                            GradientStop { position: 0.5; color: "#73ffffff" }
                            GradientStop { position: 1; color: "#00ffffff" }
                        }
                        NumberAnimation on x {
                            id: sweep
                            running: false
                            from: -glint.width
                            to: strip.width
                            duration: Theme.ms(16 * 16 + 260)
                            easing.type: Easing.InOutSine
                        }
                        Connections {
                            target: root
                            function onCurrentChanged() { if (root.t > 0) sweep.restart() }
                        }
                    }
                }
            }
        }

        ChipRow { id: chipBar; drawn: !Theme.glass }
    }
}
