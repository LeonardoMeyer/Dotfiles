import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../common"

// The quickshell bar, the profile's other bar beside waybar (bar.sh picks one, hypr/.active-bar keeps it).
// It lays out the style's modules in up to three pills, like waybar's modules-left/center/right (Module.qml
// lists them). Resting on a module grows its pill into that module's page, and every module on the same pill
// can be switched to without the card closing (Pill.qml). ALT+a tears the whole bar down and builds it again.
ShellRoot {
    id: shell

    readonly property string hypr: Quickshell.env("HOME") + "/.config/hypr"

    FileView {
        id: kindFile
        path: shell.hypr + "/.active-bar"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    readonly property bool chosen: kindFile.text().trim() === "quickshell"
    property bool stopped: false
    onChosenChanged: stopped = false

    IpcHandler {
        target: "bar"
        function refresh(): void { kindFile.reload() }
        // Stops the bar, or starts it again from scratch (ALT+a).
        function toggle(): void { shell.stopped = !shell.stopped }
        // Opens (or closes) a page on the focused monitor: network (wifi, bluetooth), audio, power, workspaces.
        function menu(name: string): void { if (bar.item) bar.item.open(name === "wifi" || name === "bluetooth" ? "network" : name, "") }
        function workspaces(): void { menu("workspaces") }
        // The island on the focused monitor, at a tab: media, timer or color.
        function island(tab: string): void { if (bar.item) bar.item.open("island", tab) }
        function close(): void { if (bar.item) bar.item.closeAll() }
        // The full-screen workspace overview, on every monitor.
        function overview(): void { if (bar.item) bar.item.overviewOpen = !bar.item.overviewOpen }
    }

    LazyLoader {
        id: bar
        active: shell.chosen && !shell.stopped

        Scope {
            id: root

            // ---- Style --------------------------------------------------------------------------------------

            // Read straight from its folder (hypr/<style>/quickshell/<name>/config.json), so editing it changes
            // the bar at once; hypr/.quickshell-bar names it (bar.sh style <name>).
            //   left/center/right  modules in each pill; only "center" gives one big pill
            //   strip              one full-width strip behind the pills
            //   background         pills draw their background while closed
            //   height, gap        pill height, and room around the pills
            //   shape              corners: round (Hyprland's rounding), capsule or square
            FileView { id: profileFile; path: shell.hypr + "/.active-profile"; watchChanges: true; printErrors: false; onFileChanged: reload() }
            FileView { id: nameFile; path: shell.hypr + "/.quickshell-bar"; watchChanges: true; printErrors: false; onFileChanged: reload() }
            FileView {
                id: lookFile
                path: shell.hypr + "/" + profileFile.text().trim().split("/")[0] + "/quickshell/" + (nameFile.text().trim() || "default") + "/config.json"
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
            }
            readonly property var look: {
                const d = { left: ["user", "workspaces"], center: ["media", "date", "timer", "clock"],
                    right: ["tray", "|", "updates", "network", "audio", "battery", "|", "power"],
                    strip: false, background: true, height: 30, gap: 6, shape: "round" }
                try { return Object.assign(d, JSON.parse(lookFile.text())) } catch (e) { return d }
            }

            readonly property int pillH: look.height
            readonly property int edge: look.gap
            // The strip windows keep clear of; open cards overlap windows instead of pushing them.
            readonly property int reserve: pillH + edge * 2

            // ---- Actions ------------------------------------------------------------------------------------

            function run(cmd) {
                Quickshell.execDetached(["sh", "-c", cmd])
            }

            // waybar's color picker, so both bars share one history. A moment first, for the card to fold away.
            function pickColor() {
                run("sleep 0.3; ~/.config/waybar/scripts/colorpicker.sh")
            }

            // Opens a page on the focused monitor's pill that has it, or closes it if it is open.
            function open(page, tab) {
                const w = windows[Hyprland.focusedMonitor?.name ?? ""]
                const p = w ? w.pills.find(p => p.visible && p.has(page)) : null
                if (!p) return
                if (tab) { p.show(page); p.tab = tab }
                else p.toggle(page)
            }
            function closeAll() {
                for (const k of Object.keys(windows)) for (const p of windows[k].pills) p.close()
            }
            property var windows: ({})

            // ---- Clock, timer and updates -------------------------------------------------------------------

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }
            readonly property date now: clock.date

            Island.Countdown {
                id: countdown
                onFinished: root.run("notify-send -a 'Focus timer' -i alarm-symbolic 'Time is up' " +
                                     "'Your " + Math.round(total / 60) + " minute session has finished.'")
            }
            readonly property alias timer: countdown

            Island.Forecast { id: forecast }
            readonly property alias weather: forecast

            // Counted every half hour, and again whenever pacman has run (from the bar or anywhere else).
            property int updates: 0
            Process {
                id: checkProc
                command: ["sh", "-c", "checkupdates 2>/dev/null | wc -l"]
                stdout: StdioCollector { onStreamFinished: root.updates = parseInt(text) || 0 }
            }
            function recount() {
                if (!checkProc.running) checkProc.running = true
            }
            Timer {
                interval: 30 * 60 * 1000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: root.recount()
            }
            FileView {
                path: "/var/log/pacman.log"
                watchChanges: true
                preload: false
                printErrors: false
                onFileChanged: pacmanRan.restart()
            }
            Timer { id: pacmanRan; interval: 3000; onTriggered: root.recount() }

            Process {
                id: updateProc
                command: ["kitty", "--title", "System update", "sh", "-c", "yay -Syu; echo; read -rp 'Done. Press enter to close.' _"]
                onExited: root.recount()
            }
            function runUpdate() {
                if (!updateProc.running) updateProc.running = true
            }

            // ---- Media --------------------------------------------------------------------------------------

            readonly property var players: Theme.players
            // Picked with the media tab's player chip; otherwise Spotify, then whatever plays, then anything.
            property string pinned: ""
            readonly property var player: {
                const ps = players
                if (!ps || ps.length === 0) return null
                return ps.find(p => p.dbusName === pinned)
                    ?? ps.find(p => Theme.isSpotify(p))
                    ?? ps.find(p => p.isPlaying)
                    ?? ps[0]
            }
            readonly property bool playing: !!player && player.isPlaying
            // The strip shows what is playing, and folds away once it stops: a few seconds' grace covers track
            // changes and quick pauses, then the art, title and waveform give way to the date.
            property bool hasMedia: false
            onPlayingChanged: {
                if (playing) { stopped.stop(); hasMedia = true }
                else stopped.restart()
            }
            onPlayerChanged: if (!player) { stopped.stop(); hasMedia = false }
            Component.onCompleted: hasMedia = playing
            Timer { id: stopped; interval: 3000; onTriggered: root.hasMedia = root.playing }

            function cyclePlayer() {
                const ps = players
                if (!ps || ps.length < 2) return
                pinned = ps[(ps.indexOf(player) + 1) % ps.length].dbusName
            }

            // ---- Music player -------------------------------------------------------------------------------

            // Where the music player's card is (music/shell.qml publishes it). While it is open it carries the
            // media, unless a pill opens over it: then it folds away until the pill closes, and the pill shows
            // the media.
            FileView {
                id: musicFile
                path: Quickshell.env("XDG_RUNTIME_DIR") + "/music-player.json"
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
            }
            readonly property var music: {
                try { return JSON.parse(musicFile.text()) } catch (e) { return { open: false } }
            }
            readonly property bool musicOut: !!music.open

            function mediaAway(pill) {
                return musicOut && !pill.tucked
            }
            function showMedia(pill) {
                return hasMedia && !mediaAway(pill)
            }

            // Whether the card a pill would open for `page` reaches over the music player.
            function musicInTheWay(pill, page) {
                const m = music
                if (!m.open || m.tucked || !pill.screen || m.screen !== pill.screen.name || m.x === undefined) return false
                const w = Math.max(pill.rowW, Math.min(pill.maxW, pill.widths[page] ?? 340))
                const p = pill.mapToItem(null, 0, 0)
                const x = pill.align === "left" ? p.x : pill.align === "right" ? p.x + pill.rowW - w : p.x + (pill.rowW - w) / 2
                const my = reserve + m.y, side = m.side || 0
                return m.x < x + w && m.x + side > x && my < p.y + pillH + 460 && my + side > p.y
            }

            // open, close, tuck (fold away while a card covers it) or untuck.
            function musicCall(call) { run("~/.config/hypr/utilities/shells.sh music " + call) }

            // ---- Workspaces ---------------------------------------------------------------------------------

            property bool overviewOpen: false
            function toggleOverview() {
                overviewOpen = !overviewOpen
            }

            // Hyprland is only read while a workspace view is up.
            Workspaces {
                id: spaces
                active: root.overviewOpen || Object.keys(root.windows).some(k => root.windows[k].pills.some(p => p.shownPage === "workspaces"))
            }
            readonly property alias expose: spaces

            Variants {
                model: Quickshell.screens
                Workspaces.Overview {
                    required property var modelData
                    screen: modelData
                    expose: root.expose
                    open: root.overviewOpen
                    onDismissed: root.overviewOpen = false
                }
            }

            // ---- Bar ----------------------------------------------------------------------------------------

            Variants {
                model: Quickshell.screens

                PanelWindow {
                    id: win

                    required property var modelData
                    screen: modelData

                    anchors {
                        top: true
                        left: true
                        right: true
                    }
                    // One fixed size, tall enough for the tallest card, so opening and closing never resize the
                    // surface (a resize makes the compositor redraw it and its blur).
                    implicitHeight: Math.min(modelData.height, root.reserve + 640)
                    exclusiveZone: root.reserve
                    color: "transparent"
                    WlrLayershell.layer: WlrLayer.Top
                    // Blurred, or glassed when hyprglass glasses layers, like the other utilities (style.lua, hyprglass.lua).
                    WlrLayershell.namespace: "quickshell-bar"
                    // The bar never takes the keyboard, except while a Wi-Fi password is being typed.
                    WlrLayershell.keyboardFocus: pills.some(p => p.holdOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                    // Only the pills and their cards take input; the rest clicks through.
                    mask: Region {
                        item: left.visible ? left.card : null
                        Region { item: center.visible ? center.card : null }
                        Region { item: right.visible ? right.card : null }
                    }

                    readonly property var pills: [left, center, right]

                    Component.onCompleted: root.windows = Object.assign({}, root.windows, { [modelData.name]: win })
                    Component.onDestruction: {
                        const w = Object.assign({}, root.windows)
                        delete w[modelData.name]
                        root.windows = w
                    }

                    // Each side pill may grow until it nearly meets the centre one; the centre one grows evenly
                    // both ways, into the room the wider side leaves.
                    readonly property real inset: root.look.strip ? root.edge : root.edge + 4
                    readonly property real gap: 8
                    readonly property real leftEnd: left.visible ? left.x + left.width : 0
                    readonly property real rightStart: right.visible ? right.x : width
                    readonly property real centerRoom: left.visible || right.visible
                        ? width - 2 * Math.max(leftEnd, width - rightStart) - 2 * gap : width - 2 * inset

                    FocusScope {
                        anchors.fill: parent
                        focus: true
                        Keys.onEscapePressed: { for (const p of win.pills) p.close() }

                        // "strip": one bar across the top, the pills sitting on it.
                        Rectangle {
                            visible: root.look.strip === true
                            width: win.width
                            height: root.reserve
                            color: Theme.alpha(Theme.bg, 0.6)
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: Theme.alpha(Theme.fg, 0.07)
                            }
                        }

                        Pill {
                            id: left
                            ctx: root
                            screen: win.modelData
                            modules: root.look.left || []
                            align: "left"
                            x: win.inset
                            maxW: (center.visible ? center.x : win.rightStart) - win.gap - x
                            hurry: center.open || right.open
                        }

                        Pill {
                            id: center
                            ctx: root
                            screen: win.modelData
                            modules: root.look.center || []
                            align: "center"
                            x: Math.round((win.width - width) / 2)
                            maxW: win.centerRoom
                            hurry: left.open || right.open
                        }

                        Pill {
                            id: right
                            ctx: root
                            screen: win.modelData
                            modules: root.look.right || []
                            align: "right"
                            x: win.width - width - win.inset
                            maxW: x + width - (center.visible ? center.x + center.width : win.leftEnd) - win.gap
                            hurry: left.open || center.open
                        }
                    }
                }
            }
        }
    }
}
