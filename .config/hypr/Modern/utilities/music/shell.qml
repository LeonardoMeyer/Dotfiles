import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets

// Music player: a square that drops out from under waybar at the top center, toggled with Alt+M (see music.sh).
// It follows Spotify when that's running, else whichever player is playing; the chip top left switches players.
// It never takes focus or closes on outside clicks: only the card itself takes input, and keys work once it's clicked.
// The bottom edge drags to resize (it stays square and centered); the size is remembered between sessions.
ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string uiPath: home + "/.local/state/music-player/ui.json"

    // The window stays mapped (empty input region) so opening never waits on surface creation.
    property bool active: false
    property bool leaving: false
    property real t: 0
    property var targetScreen: null

    // ---- Size -------------------------------------------------------------------------------------------------

    readonly property real u: {
        const s = win.screen
        if (!s) return 1
        return Math.max(0.8, Math.min(1.35, Math.min(s.width / 1920, s.height / 1080)))
    }
    readonly property real screenH: win.screen ? win.screen.height : 1080
    readonly property real defaultSide: Math.round(380 * u)
    readonly property real minSide: Math.round(300 * u)
    // Never reaches the bottom half's launcher, which rises from the other edge.
    readonly property real maxSide: Math.max(minSide, Math.round(Math.min(720 * u, screenH * 0.55)))
    property real side: defaultSide
    property real dragSide: defaultSide
    property bool dragging: false
    readonly property real shown: Math.max(minSide, Math.min(maxSide, dragging ? dragSide : side))
    Behavior on side { enabled: !root.dragging; NumberAnimation { duration: Theme.move; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

    // Everything inside is laid out for a 380px card and scales with it, so a resize never reflows.
    readonly property real k: shown / 380
    function px(v) { return Math.round(v * k) }
    readonly property real pad: px(30)

    // The profile's own rounding and outer gap, so the card sits like a window would.
    readonly property real rounding: roundingWatch.value
    property real gapsOut: 8
    readonly property real topGap: Math.max(8, gapsOut)
    readonly property real radius: Math.min(rounding, shown / 4)

    FileView {
        id: uiFile
        path: root.uiPath
        blockLoading: true
        printErrors: false
    }

    // Where the card sits while open, so the launcher can let clicks on it through instead of closing.
    readonly property string placement: JSON.stringify({
        open: active && !leaving, screen: targetScreen?.name ?? "", side: Math.round(shown), top: topGap
    })
    onPlacementChanged: placementWrite.restart()
    Timer { id: placementWrite; interval: 30; onTriggered: placementFile.setText(root.placement) }
    FileView {
        id: placementFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/music-player.json"
        atomicWrites: false
        printErrors: false
    }

    function saveSide(v) {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', "sh",
                                 uiPath, JSON.stringify({ side: v / u })])
    }

    Rounding { id: roundingWatch }

    Process {
        id: gapsProc
        command: ["hyprctl", "-j", "getoption", "general:gaps_out"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    const n = parseInt(String(d.custom ?? d.css ?? d.int ?? "").trim().split(/\s+/)[0])
                    if (!isNaN(n)) root.gapsOut = n
                } catch (e) {}
            }
        }
    }

    // ---- Players ----------------------------------------------------------------------------------------------

    readonly property var players: Mpris.players.values
    // Chosen with the chip; otherwise Spotify, then whatever is playing, then anything.
    property string pinned: ""
    readonly property var player: {
        const ps = players
        if (!ps || ps.length === 0) return null
        return ps.find(p => p.dbusName === pinned)
            ?? ps.find(p => isSpotify(p))
            ?? ps.find(p => p.isPlaying)
            ?? ps[0]
    }
    readonly property bool spotify: !!player && isSpotify(player)
    readonly property bool playing: !!player && player.isPlaying

    function isSpotify(p) {
        return (p.identity || "").toLowerCase().includes("spotify") || (p.dbusName || "").toLowerCase().includes("spotify")
    }

    function cyclePlayer() {
        const ps = players
        if (!ps || ps.length < 2) return
        const i = ps.indexOf(player)
        pinned = ps[(i + 1) % ps.length].dbusName
    }

    // Quickshell estimates position between updates; asking every frame keeps the bar gliding.
    FrameAnimation {
        running: root.active && root.playing
        onTriggered: if (root.player) root.player.positionChanged()
    }

    // The last skip's direction, so the new track slides in from that side.
    property int dir: 1
    function next() { if (player && player.canGoNext) { dir = 1; player.next() } }
    function previous() { if (player && player.canGoPrevious) { dir = -1; player.previous() } }
    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying() }
    function seekBy(s) {
        if (!player || !player.canSeek) return
        player.position = Math.max(0, Math.min(player.length, player.position + s))
    }

    // Same as the home screen's: focus an existing Spotify window; reveal it via pypr if it sits in the scratchpad;
    // otherwise launch the scratchpad.
    function openSpotify() {
        Quickshell.execDetached(["sh", "-c",
            "c=$(hyprctl clients -j | jq -c '[.[] | select(.class | test(\"^spotify$\"; \"i\"))][0] // empty'); " +
            "if [ -z \"$c\" ]; then pypr show spotify; " +
            "elif echo \"$c\" | jq -e '.workspace.name | startswith(\"special\")' >/dev/null; then pypr show spotify; " +
            "else hyprctl dispatch focuswindow address:$(echo \"$c\" | jq -r .address); fi"])
        close()
    }

    // ---- Volume -----------------------------------------------------------------------------------------------

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    function setVolume(v) {
        if (!sink || !sink.audio) return
        sink.audio.volume = Math.max(0, Math.min(1, v))
        // Moving the volume while muted would otherwise change nothing audible.
        if (v > 0 && sink.audio.muted) sink.audio.muted = false
    }
    function toggleMute() { if (sink && sink.audio) sink.audio.muted = !muted }

    function clock(s) {
        if (!(s > 0)) return "0:00"
        s = Math.floor(s)
        const m = Math.floor(s / 60), r = s % 60
        return m >= 60 ? Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0") + ":" + String(r).padStart(2, "0")
                       : m + ":" + String(r).padStart(2, "0")
    }

    // ---- Open and close ---------------------------------------------------------------------------------------

    // Drop-down morph, the launcher's mirrored: a capsule slides out from under the bar, stretches wide, then grows tall.
    readonly property real dot: Math.round(52 * u)
    readonly property real rise: Math.max(0, Math.min(1, t / 0.28))
    readonly property real mw: Math.max(0, Math.min(1.02, (t - 0.12) / 0.48))
    readonly property real mh: Math.max(0, Math.min(1.02, (t - 0.32) / 0.68))
    property real vizIntro: 0

    Component.onCompleted: {
        try {
            const ui = JSON.parse(uiFile.text())
            if (typeof ui.side === "number") side = Math.round(ui.side * u)
        } catch (e) {}
        targetScreen = focusedScreen()
        placementWrite.restart()
        roundingWatch.refresh()
        gapsProc.running = true
    }

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor
        return Quickshell.screens.find(s => s.name === mon?.name) ?? Quickshell.screens[0]
    }

    function show() {
        if (active && !leaving) return
        roundingWatch.refresh()
        gapsProc.running = true
        const scr = focusedScreen()
        if (!active && scr !== targetScreen) {
            // A different monitor needs a new surface; give it a moment before dropping.
            targetScreen = scr
            moveDelay.restart()
            return
        }
        begin()
    }

    function begin() {
        leaving = false
        active = true
        animateTo(1)
        vizAnim.restart()
    }

    function close() {
        if (!active || leaving) return
        leaving = true
        animateTo(0)
    }

    function toggleOpen() {
        if (active && !leaving) close()
        else show()
    }

    // Enter: springy, with a touch of overshoot. Exit: ease-in, so it folds up and slips back under the bar.
    function animateTo(target) {
        tween.stop()
        tween.from = t
        tween.to = target
        tween.duration = target === 1 ? 560 : 340
        tween.easing.bezierCurve = target === 1 ? [0.18, 1.12, 0.32, 1, 1, 1] : [0.45, 0, 0.8, 0.35, 1, 1]
        tween.start()
    }

    // Contents fade in once the shape is nearly full, a beat apart; on the way out they leave together first.
    function stage(from) {
        if (leaving) return Math.max(0, Math.min(1, (t - 0.7) / 0.3))
        return Math.max(0, Math.min(1, (t - from) / (1 - from)))
    }

    Timer { id: moveDelay; interval: 90; onTriggered: root.begin() }

    NumberAnimation {
        id: tween
        target: root
        property: "t"
        easing.type: Easing.BezierSpline
        onFinished: {
            if (!root.leaving) return
            root.active = false
            root.leaving = false
            root.vizIntro = 0
        }
    }

    // Waits for the card to fill out, so the center bars' pop isn't spent while still faded.
    SequentialAnimation {
        id: vizAnim
        PropertyAction { target: root; property: "vizIntro"; value: 0 }
        PauseAnimation { duration: 220 }
        NumberAnimation { target: root; property: "vizIntro"; to: 1; duration: 820; easing.type: Easing.OutQuad }
    }

    IpcHandler {
        target: "music"
        function toggle(): void { root.toggleOpen() }
        function open(): void { root.show() }
        function close(): void { root.close() }
    }

    // ---- Window -----------------------------------------------------------------------------------------------

    PanelWindow {
        id: win
        screen: root.targetScreen ?? Quickshell.screens[0]
        anchors.top: true
        // Normal exclusion keeps it below waybar's reserved strip.
        exclusionMode: ExclusionMode.Normal
        implicitWidth: root.maxSide + 48
        implicitHeight: root.maxSide + root.topGap + 48
        color: "transparent"
        // Only the card takes input, and only while open; everything around it clicks through.
        mask: Region { item: root.active && !root.leaving ? card : null }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "music-player"
        // Never grabs the keyboard; clicking the card lends it focus for the shortcuts below.
        WlrLayershell.keyboardFocus: root.active && !root.leaving ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Item {
            id: card
            width: root.dot + (root.shown - root.dot) * root.mw
            height: root.dot + (root.shown - root.dot) * root.mh
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.topGap - (1 - root.rise) * (root.dot + root.topGap + 24)
            // Solid the whole way (no faint tail for the blur to ghost on).
            opacity: root.active ? Math.min(1, root.t * 8) : 0
            focus: true

            Keys.onPressed: event => {
                const k = event.key
                if (k === Qt.Key_Escape || k === Qt.Key_Q) root.close()
                else if (k === Qt.Key_Space || k === Qt.Key_K) { playButton.bump(); root.toggle() }
                else if (k === Qt.Key_Left || k === Qt.Key_H) root.seekBy(-5)
                else if (k === Qt.Key_Right || k === Qt.Key_L) root.seekBy(5)
                else if (k === Qt.Key_Up) root.setVolume(root.volume + 0.05)
                else if (k === Qt.Key_Down) root.setVolume(root.volume - 0.05)
                else if (k === Qt.Key_M) root.toggleMute()
                else if (k === Qt.Key_N || k === Qt.Key_Period) { nextButton.bump(); root.next() }
                else if (k === Qt.Key_P || k === Qt.Key_Comma) { prevButton.bump(); root.previous() }
                else { event.accepted = false; return }
                event.accepted = true
            }

            MouseArea {
                anchors.fill: parent
                onPressed: card.forceActiveFocus()
            }

            // Matches Hyprland: the profile's rounding, translucent over compositor blur (and hyprglass where enabled).
            Rectangle {
                anchors.fill: parent
                radius: Math.min(card.height / 2, Math.max(root.radius, root.dot / 2 - (root.dot / 2 - root.radius) * Math.min(1, root.mw)))
                color: Theme.alpha(Theme.bg, 0.6)
                border.width: 1
                border.color: Theme.alpha(Theme.fg, 0.07)
            }

            // Contents keep their full-size layout and are revealed by the growing shape, so nothing reflows.
            Item {
                anchors.fill: parent
                clip: true

                Item {
                    id: content
                    width: root.shown - root.pad * 2
                    height: root.shown - root.pad * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.pad

                    // ---- Top row: player chip and the Spotify button ------------------------------------------

                    Item {
                        id: topRow
                        width: parent.width
                        height: root.px(26)
                        opacity: root.stage(0.55)
                        transform: Translate { y: -8 * (1 - root.stage(0.5)) }

                        Rectangle {
                            id: chip
                            visible: !!root.player
                            height: parent.height
                            width: chipRow.implicitWidth + root.px(20)
                            radius: height / 2
                            color: Theme.alpha(Theme.fg, chipArea.containsMouse && root.players.length > 1 ? 0.12 : 0.06)
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                            Behavior on width { NumberAnimation { duration: Theme.move; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: root.px(7)

                                // Breathes while something plays.
                                Rectangle {
                                    id: liveDot
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: root.px(6)
                                    height: width
                                    radius: width / 2
                                    color: root.playing ? Theme.accent : Theme.dim
                                    Behavior on color { ColorAnimation { duration: Theme.move } }
                                    SequentialAnimation on opacity {
                                        running: root.active && root.playing
                                        loops: Animation.Infinite
                                        onRunningChanged: if (!running) liveDot.opacity = 1
                                        NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.player ? (root.player.identity || "Player") : ""
                                    font.family: Theme.sans
                                    font.pixelSize: root.px(11)
                                    color: Theme.fg
                                }
                                Text {
                                    visible: root.players.length > 1
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ""
                                    font.family: Theme.sans
                                    font.pixelSize: root.px(9)
                                    color: Theme.dim
                                }
                            }

                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: root.players.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.cyclePlayer()
                            }
                        }

                        Glyph {
                            id: spotifyButton
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            size: root.px(30)
                            glyph: ""
                            glyphSize: root.px(19)
                            tint: root.spotify ? Theme.accent : Theme.fg
                            onClicked: root.openSpotify()
                        }

                        Volume {
                            anchors.right: spotifyButton.left
                            anchors.rightMargin: root.px(8)
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.px(116)
                        }
                    }

                    // ---- Now playing --------------------------------------------------------------------------

                    Item {
                        id: nowPlaying
                        anchors.top: topRow.bottom
                        anchors.topMargin: root.px(22)
                        width: parent.width
                        height: root.px(100)
                        opacity: root.stage(0.6)
                        transform: Translate { y: 10 * (1 - root.stage(0.55)) }

                        Art {
                            id: art
                            width: parent.height
                            height: parent.height
                            url: root.player ? (root.player.trackArtUrl || "") : ""
                        }

                        // Title and artist trade places as a unit: out toward the old side, in from the new one.
                        Item {
                            id: info
                            anchors.left: art.right
                            anchors.leftMargin: root.px(18)
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: infoCol.implicitHeight

                            readonly property string key: root.player ? root.player.trackTitle + "\u0001" + root.player.trackArtist : ""
                            property string title: ""
                            property string artist: ""
                            property string album: ""
                            property real shift: 0

                            function take() {
                                title = root.player ? (root.player.trackTitle || "Unknown track") : ""
                                artist = root.player ? (root.player.trackArtist || "") : ""
                                album = root.player ? (root.player.trackAlbum || "") : ""
                            }
                            Component.onCompleted: take()
                            onKeyChanged: {
                                if (!root.active || title === "") { take(); return }
                                swap.restart()
                            }

                            SequentialAnimation {
                                id: swap
                                ParallelAnimation {
                                    NumberAnimation { target: infoCol; property: "opacity"; to: 0; duration: 130; easing.type: Easing.InQuad }
                                    NumberAnimation { target: info; property: "shift"; to: -root.dir * 18; duration: 130; easing.type: Easing.InQuad }
                                }
                                ScriptAction { script: { info.take(); info.shift = root.dir * 18; root.dir = 1 } }
                                ParallelAnimation {
                                    NumberAnimation { target: infoCol; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: info; property: "shift"; to: 0; duration: Theme.move + 60; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle }
                                }
                            }

                            Column {
                                id: infoCol
                                width: parent.width
                                spacing: root.px(4)
                                transform: Translate { x: info.shift }

                                Text {
                                    width: parent.width
                                    text: root.player ? info.title : "Nothing playing"
                                    elide: Text.ElideRight
                                    font.family: Theme.sans
                                    font.pixelSize: root.px(17)
                                    color: Theme.bright
                                }
                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: root.player ? info.artist : "Open Spotify to start"
                                    elide: Text.ElideRight
                                    font.family: Theme.sans
                                    font.pixelSize: root.px(13)
                                    color: Theme.fg
                                }
                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: root.player ? info.album : ""
                                    elide: Text.ElideRight
                                    font.family: Theme.sans
                                    font.pixelSize: root.px(11)
                                    color: Theme.dim
                                }
                            }
                        }
                    }

                    // ---- Bottom: visualizer, controls and the seek bar stacked upward -------------------------

                    Visualizer {
                        id: viz
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: root.px(34)
                        running: root.active || moveDelay.running
                        intro: root.vizIntro
                        opacity: root.stage(0.7)
                    }

                    Item {
                        id: controls
                        anchors.bottom: viz.top
                        anchors.bottomMargin: root.px(18)
                        width: parent.width
                        height: root.px(56)
                        opacity: root.stage(0.66)
                        transform: Translate { y: 8 * (1 - root.stage(0.62)) }
                        enabled: !!root.player

                        Glyph {
                            id: prevButton
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: playButton.left
                            anchors.rightMargin: root.px(26)
                            size: root.px(44)
                            glyph: ""
                            glyphSize: root.px(16)
                            nudge: -1
                            dimmed: !root.player || !root.player.canGoPrevious
                            onClicked: root.previous()
                        }

                        PlayButton {
                            id: playButton
                            anchors.centerIn: parent
                            size: root.px(56)
                        }

                        Glyph {
                            id: nextButton
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: playButton.right
                            anchors.leftMargin: root.px(26)
                            size: root.px(44)
                            glyph: ""
                            glyphSize: root.px(16)
                            nudge: 1
                            dimmed: !root.player || !root.player.canGoNext
                            onClicked: root.next()
                        }
                    }

                    Seek {
                        id: seek
                        anchors.bottom: controls.top
                        anchors.bottomMargin: root.px(10)
                        width: parent.width
                        opacity: root.stage(0.63)
                        transform: Translate { y: 8 * (1 - root.stage(0.6)) }
                    }
                }
            }

            // Bottom edge: drag to resize. It stays square and centered; near the default it snaps back to it.
            Item {
                id: grab
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.px(90)
                height: root.px(16)
                opacity: root.stage(0.75)

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.px(7)
                    height: 4
                    width: grabArea.containsMouse || grabArea.pressed ? root.px(64) : root.px(36)
                    radius: 2
                    color: Theme.alpha(grabArea.containsMouse || grabArea.pressed ? Theme.accent : Theme.fg, grabArea.containsMouse || grabArea.pressed ? 0.85 : 0.18)
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }

                MouseArea {
                    id: grabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SizeVerCursor
                    preventStealing: true

                    property real startY: 0
                    property real startSide: 0

                    function windowY(mouse) {
                        return mapToItem(win.contentItem, mouse.x, mouse.y).y
                    }

                    onPressed: mouse => {
                        startY = windowY(mouse)
                        startSide = root.shown
                        root.dragSide = root.shown
                        root.dragging = true
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        // Gentle resistance past either end, so the limits feel soft rather than hit.
                        const want = startSide + (windowY(mouse) - startY)
                        const lo = root.minSide, hi = root.maxSide
                        root.dragSide = want < lo ? lo - Math.sqrt(lo - want) * 2
                                      : want > hi ? hi + Math.sqrt(want - hi) * 2 : want
                    }
                    onReleased: {
                        root.side = Math.max(root.minSide, Math.min(root.maxSide, root.dragSide))
                        root.dragging = false
                        let next = root.side
                        if (Math.abs(next - root.defaultSide) < 14) next = root.defaultSide
                        root.side = next
                        root.saveSide(next)
                    }
                }
            }
        }
    }

    // ---- Pieces -----------------------------------------------------------------------------------------------

    // A round icon button: a soft disc fades in on hover, presses sink, and `nudge` kicks the glyph that way on click.
    component Glyph: Item {
        id: btn
        property real size: 40
        property string glyph: ""
        property real glyphSize: 16
        property color tint: Theme.fg
        property int nudge: 0
        property bool dimmed: false
        property real kick: 0
        signal clicked()

        width: size
        height: size

        function bump() { kickAnim.restart() }

        SequentialAnimation {
            id: kickAnim
            NumberAnimation { target: btn; property: "kick"; to: 1; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: btn; property: "kick"; to: 0; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.alpha(Theme.fg, area.pressed ? 0.16 : 0.09)
            opacity: area.containsMouse && !btn.dimmed ? 1 : 0
            scale: area.containsMouse ? 1 : 0.7
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            Behavior on scale { NumberAnimation { duration: Theme.move; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
        }

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            font.family: Theme.sans
            font.pixelSize: btn.glyphSize
            color: btn.dimmed ? Theme.dim : (area.containsMouse ? Theme.bright : btn.tint)
            opacity: btn.dimmed ? 0.5 : 1
            scale: (area.pressed ? 0.84 : 1) * (1 + 0.08 * btn.kick * (btn.nudge === 0 ? 1 : 0))
            transform: Translate { x: btn.nudge * btn.kick * root.px(6) }
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2 } }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.dimmed ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                if (btn.dimmed) return
                btn.bump()
                btn.clicked()
            }
        }
    }

    // The home screen's volume bar, pill-sized: click or drag along it, wheel over it, the speaker toggles mute.
    component Volume: Item {
        id: vb
        height: root.px(24)
        readonly property real level: root.muted ? 0 : root.volume

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.alpha(Theme.fg, volDrag.containsMouse || volDrag.pressed ? 0.14 : 0.08)
            clip: true
            Behavior on color { ColorAnimation { duration: Theme.fast } }

            Rectangle {
                height: parent.height
                width: Math.max(parent.height, parent.width * vb.level)
                radius: height / 2
                color: root.muted ? Theme.dim : Theme.accent
                // Follows the pointer exactly while dragging, eases otherwise.
                Behavior on width { enabled: !volDrag.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.fast } }
            }
        }

        Text {
            x: root.px(8)
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted || root.volume === 0 ? "\uf026" : "\uf028"
            font.family: Theme.sans
            font.pixelSize: root.px(12)
            color: Theme.bg
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: root.px(9)
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "Muted" : Math.round(root.volume * 100) + "%"
            font.family: Theme.sans
            font.pixelSize: root.px(10)
            color: vb.level > 0.8 ? Theme.bg : Theme.fg
        }

        MouseArea {
            id: volDrag
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: mouse => root.setVolume(mouse.x / width)
            onPositionChanged: mouse => { if (pressed) root.setVolume(mouse.x / width) }
            onWheel: wheel => root.setVolume(root.volume + wheel.angleDelta.y / 120 * 0.03)
        }
        MouseArea {
            width: parent.height
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleMute()
        }
    }

    // The accent disc with the morphing glyph; each toggle sends a ring out from its edge.
    component PlayButton: Item {
        id: pb
        property real size: 56
        property real ring: 1
        width: size
        height: size

        function bump() { ringAnim.restart() }

        NumberAnimation { id: ringAnim; target: pb; property: "ring"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }

        Rectangle {
            anchors.centerIn: parent
            width: pb.size * (1 + 0.45 * pb.ring)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            opacity: 0.55 * (1 - pb.ring)
        }

        Rectangle {
            id: disc
            anchors.fill: parent
            radius: width / 2
            color: Theme.accent
            scale: pbArea.pressed ? 0.9 : (pbArea.containsMouse ? 1.05 : 1)
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }

            PlayPause {
                anchors.centerIn: parent
                width: Math.round(pb.size * 0.34)
                height: width
                color: Theme.bg
                m: root.playing ? 1 : 0
                Behavior on m { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
            }
        }

        MouseArea {
            id: pbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                pb.bump()
                root.toggle()
            }
        }
    }

    // Seek bar with times under its ends. Hover thickens it and brings out the knob; dragging previews, release seeks.
    component Seek: Item {
        id: sk
        height: root.px(36)

        readonly property real length: root.player && root.player.lengthSupported ? root.player.length : 0
        readonly property real position: root.player && root.player.positionSupported ? root.player.position : 0
        readonly property bool live: sk.length > 0 && !!root.player && root.player.canSeek
        property bool seeking: false
        property real seekFrac: 0
        readonly property real frac: seeking ? seekFrac : (length > 0 ? Math.max(0, Math.min(1, position / length)) : 0)
        readonly property bool hot: bar.containsMouse || bar.pressed

        Item {
            id: track
            width: parent.width
            height: root.px(14)

            Rectangle {
                id: groove
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: sk.hot ? root.px(6) : root.px(4)
                radius: height / 2
                color: Theme.alpha(Theme.fg, 0.14)
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: Math.max(height, parent.width * sk.frac)
                    color: Theme.accent
                    // Glides to a new spot (a new track, a seek) but tracks the playhead and the pointer directly.
                    Behavior on width {
                        enabled: !sk.seeking
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: groove.width * sk.frac - width / 2
                width: root.px(14)
                height: width
                radius: width / 2
                color: Theme.bright
                scale: sk.hot && sk.live ? (bar.pressed ? 1.15 : 1) : 0
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2 } }
            }

            MouseArea {
                id: bar
                anchors.fill: parent
                anchors.margins: -root.px(6)
                hoverEnabled: true
                enabled: sk.live
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function fracAt(mouse) {
                    return Math.max(0, Math.min(1, (mouse.x - root.px(6)) / groove.width))
                }
                onPressed: mouse => { sk.seekFrac = fracAt(mouse); sk.seeking = true }
                onPositionChanged: mouse => { if (pressed) sk.seekFrac = fracAt(mouse) }
                onReleased: {
                    if (root.player && root.player.canSeek) root.player.position = sk.seekFrac * sk.length
                    sk.seeking = false
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: root.clock(sk.frac * sk.length)
            font.family: Theme.sans
            font.pixelSize: root.px(11)
            color: sk.seeking ? Theme.bright : Theme.dim
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }
        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: sk.length > 0 ? root.clock(sk.length) : "--:--"
            font.family: Theme.sans
            font.pixelSize: root.px(11)
            color: Theme.dim
        }
    }

    // Album art that cross-fades: a new cover loads behind the current one and fades in once it's ready.
    component Art: Item {
        id: art
        property string url: ""
        property bool useA: true

        // Whichever image already holds the new cover shows at once; otherwise the hidden one loads it and swaps
        // in when ready. Re-setting an unchanged source never re-fires onStatusChanged, so that case can't wait on it.
        onUrlChanged: {
            const front = useA ? imgA : imgB
            const back = useA ? imgB : imgA
            if (url !== "" && front.source == url) return
            if (url !== "" && back.source == url && back.status !== Image.Loading) { swapTo(back); return }
            back.source = url
            if (url === "") swapTo(back)
        }

        function swapTo(img) {
            useA = img === imgA
        }
        // A cover that can't load falls back to the placeholder rather than leaving the last track's up.
        function settled(img) {
            if (img.source != url) return
            if (img.status === Image.Ready || img.status === Image.Error) swapTo(img)
        }

        Rectangle {
            anchors.fill: parent
            radius: root.px(12)
            color: Theme.alpha(Theme.fg, 0.07)

            Text {
                anchors.centerIn: parent
                text: ""
                font.family: Theme.sans
                font.pixelSize: root.px(30)
                color: Theme.dim
            }
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: root.px(12)
            color: "transparent"

            Image {
                id: imgA
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
                sourceSize: Qt.size(256, 256)
                opacity: art.useA && status === Image.Ready ? 1 : 0
                scale: art.useA ? 1 : 1.04
                onStatusChanged: art.settled(imgA)
                Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
            }
            Image {
                id: imgB
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
                sourceSize: Qt.size(256, 256)
                opacity: !art.useA && status === Image.Ready ? 1 : 0
                scale: !art.useA ? 1 : 1.04
                onStatusChanged: art.settled(imgB)
                Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
            }
        }
    }
}
