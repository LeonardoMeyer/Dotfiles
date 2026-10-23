import QtQuick
import QtQuick.Effects
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
    // The entrance waits for the backdrop so its first blur render never lands mid-animation.
    property bool backdropReady: false
    property bool startWaited: false
    // Chosen wallpaper until wallpaper-apply.sh has written it to the cache.
    property string pendingPath: ""

    // Hyprland's live rounding (override or profile default) for the wallpaper cards.

    // The stage lays out in a fixed 1600x900 space and is scaled to the screen; portrait fits 1100 units across instead.
    readonly property real u: unitFor(win.screen)

    function unitFor(s) {
        if (!s) return 1
        const v = s.height > s.width
            ? Math.min(s.width / 1100, s.height / 1000)
            : Math.min(s.width / 1600, s.height / 900)
        return Math.max(0.5, v)
    }
    readonly property string backdropSrc: current ? "file://" + current.thumb : ""
    readonly property var current: items.length > 0 ? items[Math.max(0, Math.min(cur, items.length - 1))] : null
    readonly property var palette: current ? current.colors : []
    property color accent: palette.length > 9 ? palette[9] : "#ffffff"
    // Darkest to lightest so the strip blends smoothly.
    readonly property var ramp: palette.length === 16
        ? palette.slice().sort((a, b) => lum(a) - lum(b))
        : []

    function lum(c) {
        const q = Qt.color(c)
        return 0.2126 * q.r + 0.7152 * q.g + 0.0722 * q.b
    }

    Behavior on pos { id: posBehavior; NumberAnimation { duration: Theme.ms(380); easing.type: Easing.OutCubic } }
    Behavior on accent { ColorAnimation { duration: Theme.ms(350) } }

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
        if (applied === pendingPath) pendingPath = ""
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
        Quickshell.execDetached([home + "/.config/hypr/utilities/wallpaper-apply.sh", current.path])
        close()
    }

    function show() {
        Theme.refresh()
        watchdog.stop()
        if ((shown && !leaving) || locating) return
        locating = true
        Theme.locate(open)
    }

    function open(screen) {
        locating = false
        if (shown && !leaving) return
        leaving = false
        t = 0
        backdropReady = false
        startWaited = false
        if (!current || current.path !== landing) rebuild(landing)
        // Frozen for this open so moving the cursor to another monitor never drags the window along.
        targetScreen = screen
        shown = true
        backdropReady = backdrop.settled
        startTimer.restart()
        waitTimer.restart()
        Qt.callLater(() => stage.forceActiveFocus())
    }

    function toggle() {
        if (shown && !leaving) close()
        else show()
    }

    // Unmapping (rather than exiting) hands focus and the pointer straight back to the desktop.
    function finish() {
        watchdog.stop()
        startTimer.stop()
        waitTimer.stop()
        tween.stop()
        shown = false
        leaving = false
        t = 0
        if (theme !== "all") theme = "all"
        rebuild(landing)
    }

    // Last resort: a stalled close must never leave the full-screen surface grabbing input.
    Timer { id: watchdog; interval: Theme.ms(1200) + 100; onTriggered: root.finish() }

    function animateTo(target) {
        tween.stop()
        tween.from = t
        tween.to = target
        tween.duration = Theme.ms(target === 1 ? 900 : 320)
        tween.easing.type = target === 1 ? Easing.OutCubic : Easing.InOutCubic
        tween.start()
    }

    function tryStart() {
        if (shown && !leaving && !tween.running && t === 0 && (backdropReady || startWaited)) animateTo(1)
    }

    function close() {
        if (!shown || leaving) return
        leaving = true
        startTimer.stop()
        waitTimer.stop()
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
    Timer { id: waitTimer; interval: 450; onTriggered: { root.startWaited = true; root.tryStart() } }

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
        onExited: idx.running = true
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
        // Swaps without a fade, for use while the entrance is still running.
        property bool instant: false
        property bool blurred: false
        property var front: imgA
        readonly property var back: front === imgA ? imgB : imgA
        readonly property bool settled: src !== "" && front.status === Image.Ready && front.source.toString() === src
        property int zTop: 0

        // The blur renders at half size, which is indistinguishable at this radius and far cheaper per fade frame.
        layer.enabled: blurred
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, width / 2), Math.max(1, height / 2))
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 32
            blur: 1
            brightness: -0.1
            saturation: 0.12
        }

        function promote(img) {
            img.z = ++zTop
            img.opacity = 0
            fade.target = img
            fade.duration = Theme.ms(instant ? 0 : 220)
            fade.restart()
            front = img
        }

        onSrcChanged: {
            if (src === "") return
            fade.complete()
            const b = back
            if (b.source.toString() === src) {
                if (b.status === Image.Ready) promote(b)
            } else {
                b.source = src
            }
        }

        NumberAnimation { id: fade; property: "opacity"; from: 0; to: 1; duration: Theme.ms(220); easing.type: Easing.OutCubic }

        Image {
            id: imgA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            onStatusChanged: if (status === Image.Ready && source.toString() === ci.src && ci.back === imgA) ci.promote(imgA)
        }
        Image {
            id: imgB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0
            onStatusChanged: if (status === Image.Ready && source.toString() === ci.src && ci.back === imgB) ci.promote(imgB)
        }
    }

    // Other monitors preview the selected wallpaper, blurred and dimmed, so a second screen never sits bright beside the picker.
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: side
            required property var modelData
            readonly property real su: Math.max(0.6, root.unitFor(modelData))

            screen: modelData
            visible: root.shown && modelData !== win.screen
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "wallpaper-picker"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Item {
                anchors.fill: parent
                // Never 0: Qt skips invisible items, which would defer the blur's first render into the animation.
                opacity: Math.max(0.001, Math.min(1, root.t * 2.5))

                CrossImage {
                    anchors.fill: parent
                    src: root.backdropSrc
                    blurred: true
                    instant: root.t < 1
                    scale: 1 + 0.03 * root.t
                }
                Rectangle { anchors.fill: parent; color: "#66000000" }

                Text {
                    anchors.centerIn: parent
                    opacity: root.seg(0.15)
                    text: root.current ? root.current.name.replace(/[_-]/g, " ") : ""
                    width: Math.min(implicitWidth, parent.width * 0.7)
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.family: "CodeNewRoman Nerd Font Propo"
                    font.pixelSize: 28 * side.su
                    font.weight: Font.Light
                    color: "#ffffff"
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }
    }

    PanelWindow {
        id: win
        visible: root.shown
        screen: root.targetScreen ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wallpaper-picker"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

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

            // Backdrop: the focused wallpaper's thumbnail, blurred and cross-faded under a scrim.
            Item {
                anchors.fill: parent
                // Never 0: Qt skips invisible items, which would defer the blur's first render into the animation.
                opacity: Math.max(0.001, Math.min(1, root.t * 2.5))
                scale: 1 + 0.03 * root.t

                CrossImage {
                    id: backdrop
                    anchors.fill: parent
                    src: root.backdropSrc
                    blurred: true
                    instant: root.t < 1
                    onSettledChanged: if (settled) { root.backdropReady = true; startTimer.restart() }
                }
                Rectangle { anchors.fill: parent; color: "#80000000" }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
                onWheel: wheel => root.go(root.cur + (wheel.angleDelta.y + wheel.angleDelta.x < 0 ? 1 : -1))
            }

            // Theme chips: one highlight glides between them, like the launcher's and settings' tabs.
            Item {
                id: chipBar
                anchors.top: parent.top
                anchors.topMargin: 56
                anchors.horizontalCenter: parent.horizontalCenter
                width: chips.width
                height: chips.height
                opacity: Math.max(0.001, root.seg(0))
                transform: Translate { y: (1 - root.seg(0)) * -18 }

                property Item sel: null
                // The first placement after (re)building the chips lands without sliding in from the left.
                property bool settled: false

                Rectangle {
                    visible: !!chipBar.sel
                    x: chipBar.sel ? chipBar.sel.x : 0
                    width: chipBar.sel ? chipBar.sel.width : 0
                    height: 36
                    radius: 18
                    color: "#33ffffff"
                    border.width: 1
                    border.color: "#55ffffff"
                    Behavior on x { enabled: chipBar.settled; NumberAnimation { duration: Theme.ms(280); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
                    Behavior on width { enabled: chipBar.settled; NumberAnimation { duration: Theme.ms(280); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
                }

                Row {
                    id: chips
                    spacing: 8
                    Repeater {
                        model: root.themes
                        onItemAdded: { chipBar.settled = false; settleChips.restart() }
                        delegate: Item {
                            id: chip
                            required property string modelData
                            readonly property bool active: root.theme === modelData
                            onActiveChanged: if (active) chipBar.sel = chip
                            Component.onCompleted: if (active) chipBar.sel = chip
                            width: label.implicitWidth + 36
                            height: 36
                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: chip.modelData
                                font.family: "CodeNewRoman Nerd Font Propo"
                                font.pixelSize: 14
                                color: chip.active ? "#ffffff" : "#99ffffff"
                                Behavior on color { ColorAnimation { duration: Theme.ms(250) } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { root.theme = chip.modelData; root.rebuild() }
                            }
                        }
                    }
                }
                Timer { id: settleChips; interval: 50; onTriggered: chipBar.settled = true }
            }

            // Coverflow wheel: cards turn about the vertical axis and recede front to back.
            Item {
                id: wheel
                anchors.left: parent.left
                opacity: Math.max(0.001, root.seg(0.08))
                scale: 0.94 + 0.06 * root.seg(0.08)
                transform: Translate { y: (1 - root.seg(0.08)) * 36 }
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -40
                height: 360

                readonly property real cardW: 560
                readonly property real cardH: 330

                Repeater {
                    model: root.items
                    delegate: Item {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property real d: index - root.pos
                        readonly property real ad: Math.abs(d)
                        readonly property real side: Math.max(-1, Math.min(1, d))
                        readonly property bool near: ad < 5.5
                        // Wider than visible so thumbnails are decoded before a card scrolls into view.
                        readonly property bool warm: ad < 10

                        visible: near
                        width: wheel.cardW
                        height: wheel.cardH
                        y: (wheel.height - height) / 2
                        x: wheel.width / 2 - width / 2
                           + (ad <= 1 ? d * width * 0.78
                                      : (d < 0 ? -1 : 1) * (width * 0.78 + (ad - 1) * width * 0.24))
                        z: 100 - ad * 10
                        antialiasing: true
                        scale: 1.08 - 0.22 * Math.min(ad, 1) - 0.05 * Math.min(Math.max(ad - 1, 0), 3)
                        opacity: Math.max(0, 1 - 0.28 * Math.max(ad - 1, 0))

                        transform: Rotation {
                            origin.x: card.width / 2
                            origin.y: card.height / 2
                            axis { x: 0; y: 1; z: 0 }
                            angle: -card.side * 58
                        }

                        Loader {
                            anchors.fill: parent
                            active: card.warm
                            sourceComponent: frame
                        }

                        Component {
                            id: frame
                            ClippingRectangle {
                                // The stage is scaled by u, so this undoes it to land on Hyprland's own pixels.
                                radius: Theme.rounding / root.u
                                // Drawn once with multisampling and then scaled and turned as a smooth texture, so the
                                // thin border stays clean instead of breaking up into jagged pixels.
                                layer.enabled: true
                                layer.smooth: true
                                layer.samples: 4
                                antialiasing: true
                                color: "#1fffffff"
                                border.width: 1
                                border.color: card.ad < 0.5 ? "#80ffffff" : "#40ffffff"
                                Behavior on border.color { ColorAnimation { duration: Theme.ms(250) } }

                                ClippingRectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: Math.max(0, Theme.rounding / root.u - 1)
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
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: card.index === root.cur ? root.apply() : root.go(card.index)
                        }
                    }
                }
            }

            // Name and pywal grid for the focused wallpaper
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: wheel.bottom
                anchors.topMargin: 56
                spacing: 18
                opacity: Math.max(0.001, root.seg(0.22))
                transform: Translate { y: (1 - root.seg(0.22)) * 24 }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.current ? root.current.name.replace(/[_-]/g, " ") : ""
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 700)
                    horizontalAlignment: Text.AlignHCenter
                    font.family: "CodeNewRoman Nerd Font Propo"
                    font.pixelSize: 18
                    color: "#ffffff"
                }

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 520
                    height: 40

                    ClippingRectangle {
                        id: strip
                        width: parent.width
                        height: 8
                        radius: 3
                        color: "#22ffffff"

                        Rectangle {
                            id: fill
                            height: parent.height
                            width: parent.width
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                            GradientStop { position: 0.0000; color: root.ramp.length > 0 ? root.ramp[0] : "transparent" }
                            GradientStop { position: 0.0667; color: root.ramp.length > 1 ? root.ramp[1] : "transparent" }
                            GradientStop { position: 0.1333; color: root.ramp.length > 2 ? root.ramp[2] : "transparent" }
                            GradientStop { position: 0.2000; color: root.ramp.length > 3 ? root.ramp[3] : "transparent" }
                            GradientStop { position: 0.2667; color: root.ramp.length > 4 ? root.ramp[4] : "transparent" }
                            GradientStop { position: 0.3333; color: root.ramp.length > 5 ? root.ramp[5] : "transparent" }
                            GradientStop { position: 0.4000; color: root.ramp.length > 6 ? root.ramp[6] : "transparent" }
                            GradientStop { position: 0.4667; color: root.ramp.length > 7 ? root.ramp[7] : "transparent" }
                            GradientStop { position: 0.5333; color: root.ramp.length > 8 ? root.ramp[8] : "transparent" }
                            GradientStop { position: 0.6000; color: root.ramp.length > 9 ? root.ramp[9] : "transparent" }
                            GradientStop { position: 0.6667; color: root.ramp.length > 10 ? root.ramp[10] : "transparent" }
                            GradientStop { position: 0.7333; color: root.ramp.length > 11 ? root.ramp[11] : "transparent" }
                            GradientStop { position: 0.8000; color: root.ramp.length > 12 ? root.ramp[12] : "transparent" }
                            GradientStop { position: 0.8667; color: root.ramp.length > 13 ? root.ramp[13] : "transparent" }
                            GradientStop { position: 0.9333; color: root.ramp.length > 14 ? root.ramp[14] : "transparent" }
                            GradientStop { position: 1.0000; color: root.ramp.length > 15 ? root.ramp[15] : "transparent" }
                            }
                        }

                        NumberAnimation {
                            id: wipe
                            target: fill
                            property: "opacity"
                            from: 0.35
                            to: 1
                            duration: Theme.ms(260)
                            easing.type: Easing.OutCubic
                        }
                        Connections {
                            target: root
                            function onCurrentChanged() { wipe.restart() }
                        }
                    }

                    Text {
                        anchors.top: strip.bottom
                        anchors.topMargin: 12
                        text: root.ramp.length > 0 ? root.ramp[0].toString().toUpperCase() : ""
                        font.family: "CodeNewRoman Nerd Font Propo"
                        font.pixelSize: 15
                        font.letterSpacing: 1
                        color: "#88ffffff"
                    }
                    Text {
                        anchors.top: strip.bottom
                        anchors.topMargin: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.palette.length > 9 ? root.palette[9].toString().toUpperCase() : ""
                        font.family: "CodeNewRoman Nerd Font Propo"
                        font.pixelSize: 15
                        font.letterSpacing: 1
                        color: root.accent
                    }
                    Text {
                        anchors.top: strip.bottom
                        anchors.topMargin: 12
                        anchors.right: parent.right
                        text: root.ramp.length > 0 ? root.ramp[15].toString().toUpperCase() : ""
                        font.family: "CodeNewRoman Nerd Font Propo"
                        font.pixelSize: 15
                        font.letterSpacing: 1
                        color: "#88ffffff"
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.items.length > 0 ? (root.cur + 1) + " / " + root.items.length : ""
                    font.family: "CodeNewRoman Nerd Font Propo"
                    font.pixelSize: 12
                    color: root.accent
                }
            }
        }
    }
}
