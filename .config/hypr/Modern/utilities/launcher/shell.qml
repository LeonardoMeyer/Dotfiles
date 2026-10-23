import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../common"

// App launcher: a panel rising from the bottom edge, toggled by tapping Super (see shells.sh).
// Apps are a searchable icon grid ranked by how often you open them, Home is a dial of session actions,
// Commands is every bash command on a wheel, and Keybinds reads the live shortcuts.lua.
ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string helper: Quickshell.shellPath("launcher/launcher.py")
    // Terminal for Terminal=true entries and shell commands.
    readonly property string terminal: "kitty"
    // Usage counts per tab ("<count> <key>" per line), created on first start.
    readonly property string cacheDir: home + "/.cache/launcher"
    readonly property string appCache: cacheDir + "/apps"
    readonly property string homeCache: cacheDir + "/commands"
    readonly property string shellCache: cacheDir + "/shell"
    readonly property string bindCache: cacheDir + "/keybinds"

    // The window stays mapped (empty input region) so opening never waits on surface creation.
    property bool active: false
    property bool leaving: false
    property real t: 0         // enter/exit progress
    property real gridIntro: 1
    property var targetScreen: null

    // Order here is the tab bar's order; everything else refers to tabs by id.
    readonly property var tabs: [
        { id: "home", label: "Home", title: "Home", icon: "", search: "" },
        { id: "apps", label: "Apps", title: "Applications", icon: "", search: "Search apps" },
        { id: "commands", label: "Commands", title: "Commands", icon: "", search: "Search commands" },
        { id: "keybinds", label: "Keybinds", title: "Keybinds", icon: "", search: "Search keybinds" }
    ]
    // Opening without a tab named lands on Home; typing there still jumps to the app search.
    readonly property int homeTab: tabIndex("home")
    property int tab: homeTab
    readonly property string tabId: tabs[tab].id
    function tabIndex(id) { return tabs.findIndex(x => x.id === id) }
    readonly property bool searchable: tabs[tab].search !== ""
    property real introHome: 0
    property real introBinds: 0

    // Layout, per screen. Quickshell sizes are logical pixels, so fractional scaling is already applied.
    readonly property real u: {
        const s = win.screen
        if (!s) return 1
        return Math.max(0.8, Math.min(1.35, Math.min(s.width / 1920, s.height / 1080)))
    }
    readonly property int cols: 4
    readonly property real cell: Math.round(70 * u)
    readonly property real gap: Math.round(26 * u)
    // The highlight keeps the margin it had with the original 14px spacing.
    readonly property real hlPad: Math.round(Math.round(14 * u) * 0.6) * 0.6
    readonly property real gridInset: Math.max(hlPad + 4, Math.round(gap * 0.4))
    readonly property real pad: Math.round(18 * u)
    readonly property real cardW: cols * cell + (cols - 1) * gap + gridInset * 2 + pad * 2
    readonly property real cardH: Math.round(Math.min((win.screen ? win.screen.height : 1080) * 0.72, 580 * u))

    // OSD-style morph: a small half-capsule rises out of the bottom edge, stretches wide, then grows tall.
    readonly property real dot: Math.round(52 * u)
    readonly property real rise: Math.max(0, Math.min(1, t / 0.28))
    readonly property real mw: Math.max(0, Math.min(1.02, (t - 0.12) / 0.48))
    readonly property real mh: Math.max(0, Math.min(1.02, (t - 0.32) / 0.68))

    // ---- Apps ------------------------------------------------------------------------------------------------

    property var drun: ({ hide: [], paths: {} })
    property var appUses: ({})
    property var apps: []
    property var results: []
    property var slots: ({})
    property int selected: 0
    property bool searchPinned: false
    readonly property string query: search.text
    readonly property var picked: results.length > 0 ? results[Math.min(selected, results.length - 1)] : null

    // Hidden/OnlyShowIn/NotShowIn/TryExec come from the helper; Quickshell already drops NoDisplay.
    Process {
        id: scan
        command: ["python3", root.helper, "apps"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.drun = JSON.parse(text) } catch (e) {}
                rebuild.restart()
            }
        }
    }

    // Entries arrive one at a time at startup; settle before building icons.
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { rebuild.restart(); rescan.restart() }
    }
    Timer { id: rebuild; interval: 120; onTriggered: root.buildApps() }
    Timer { id: rescan; interval: 1500; onTriggered: scan.running = true }

    // The music player publishes where its card sits (see music/shell.qml).
    readonly property var music: {
        try { return JSON.parse(musicFile.text()) } catch (e) { return { open: false } }
    }
    FileView {
        id: musicFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/music-player.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    // A FileView only watches a file that existed when it loaded, so create missing caches, then reload.
    Process {
        running: true
        command: ["python3", root.helper, "init", root.appCache, root.homeCache, root.shellCache, root.bindCache]
        onExited: {
            appCacheFile.reload()
            homeCacheFile.reload()
            shellCacheFile.reload()
            bindCacheFile.reload()
        }
    }

    FileView {
        id: appCacheFile
        path: root.appCache
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.appUses = root.counts(text())
    }

    function counts(text) {
        const out = {}
        for (const line of (text || "").split("\n")) {
            const m = line.match(/^(\d+) (.+)$/)
            if (m) out[m[2]] = (out[m[2]] || 0) + parseInt(m[1])
        }
        return out
    }

    function bump(cache, key) {
        if (key) Quickshell.execDetached(["python3", helper, "bump", cache, key])
    }

    // A new apps array recreates every icon, so only replace it when the visible set actually changed.
    property string appsKey: ""
    function buildApps() {
        const hide = new Set(drun.hide || [])
        const paths = drun.paths || {}
        const list = DesktopEntries.applications.values
            .filter(e => !e.noDisplay && !hide.has(e.id) && e.name !== "")
            .sort((a, b) => a.name.localeCompare(b.name))
        const key = list.map(e => e.id + "\u0001" + e.name + "\u0001" + e.icon + "\u0001" + (paths[e.id] || "")).join("\u0002")
        if (key === appsKey) return
        appsKey = key
        apps = list.map((e, i) => ({
            id: e.id,
            entry: e,
            name: e.name,
            icon: e.icon,
            order: i,
            path: (drun.paths || {})[e.id] || "",
            n: e.name.toLowerCase(),
            words: e.name.toLowerCase().split(/[\s\-_.]+/),
            g: (e.genericName || "").toLowerCase(),
            kw: (e.keywords || []).map(k => k.toLowerCase()),
            idl: e.id.toLowerCase(),
            c: (e.comment || "").toLowerCase()
        }))
        refresh()
    }

    function subsequence(s, q) {
        let j = 0
        for (let i = 0; i < s.length && j < q.length; i++) if (s[i] === q[j]) j++
        return j === q.length
    }

    // Coarse tiers, so within a tier the grid keeps its usual order and icons move as little as possible.
    function score(a, q) {
        if (a.n === q) return 100
        if (a.n.startsWith(q)) return 90
        if (a.words.some(w => w.startsWith(q))) return 80
        if (a.n.includes(q)) return 70
        if (a.g.includes(q)) return 55
        if (a.kw.some(k => k.startsWith(q))) return 50
        if (a.idl.includes(q)) return 45
        if (q.length > 2 && a.c.includes(q)) return 30
        if (subsequence(a.n, q)) return 20
        return 0
    }

    // Most used first, then by name; a query ranks by match quality first.
    function refresh() {
        const q = query.trim().toLowerCase()
        const hits = []
        for (const a of apps) {
            const s = q === "" ? 1 : score(a, q)
            if (s > 0) hits.push({ a: a, s: s, u: appUses[a.path] || 0 })
        }
        hits.sort((x, y) => y.s - x.s || y.u - x.u || x.a.order - y.a.order)
        const map = {}
        hits.forEach((h, i) => map[h.a.id] = i)
        results = hits.map(h => h.a)
        slots = map
        selected = 0
        grid.mouseMoved = false
        grid.scrollTo(0)
    }

    onQueryChanged: refresh()

    function launch(a) {
        if (!a) return
        if (a.entry.runInTerminal) Quickshell.execDetached([terminal, "-e"].concat(a.entry.command))
        else a.entry.execute()
        bump(appCache, a.path)
        close()
    }

    function moveSelection(d) {
        const n = results.length
        if (n === 0) return
        const s = selected + d
        // Up from the first row and down from the last stay put rather than wrapping.
        if (s < 0 || (s > n - 1 && Math.floor(selected / cols) === Math.floor((n - 1) / cols))) return
        selected = Math.max(0, Math.min(n - 1, s))
    }

    // ---- Home, Commands and Keybinds -------------------------------------------------------------------------

    FileView {
        id: homeCacheFile
        path: root.homeCache
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    FileView {
        id: shellCacheFile
        path: root.shellCache
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    FileView {
        id: bindCacheFile
        path: root.bindCache
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    property var shellCommands: []
    Process {
        id: scanCommands
        command: ["python3", root.helper, "commands"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.shellCommands = JSON.parse(text) } catch (e) {}
            }
        }
    }

    NumberAnimation { id: introHomeAnim; target: root; property: "introHome"; from: 0; to: 1; duration: Theme.ms(520) }
    NumberAnimation { id: introBindsAnim; target: root; property: "introBinds"; from: 0; to: 1; duration: Theme.ms(520) }
    NumberAnimation { id: gridIntroAnim; target: root; property: "gridIntro"; from: 0; to: 1; duration: Theme.ms(720) }

    function replayIntro() {
        if (tabId === "apps") gridIntroAnim.restart()
        else if (tabId === "home") introHomeAnim.restart()
        else if (tabId === "keybinds") introBindsAnim.restart()
    }

    function runHome(id, cmd, afterClose) {
        bump(homeCache, id)
        close()
        // Anything that opens its own surface waits for the panel to finish leaving.
        Quickshell.execDetached(["sh", "-c", (afterClose ? "sleep 0.3; " : "") + cmd])
    }

    // Interactive bash, so .bashrc aliases and functions work; kitty --hold leaves a prompt behind when it finishes.
    function runShell(cmd, key, background) {
        bump(shellCache, key)
        close()
        if (background) Quickshell.execDetached(["bash", "-ic", cmd])
        else Quickshell.execDetached([terminal, "--hold", "bash", "-ic", cmd])
    }

    // ---- Tabs, focus and keys --------------------------------------------------------------------------------

    function setTab(i) {
        i = Math.max(0, Math.min(tabs.length - 1, i))
        if (i !== tab) {
            tab = i
            replayIntro()
        }
        focusTab()
    }

    function focusTab() {
        if (searchable) search.input.forceActiveFocus()
        else keyRoot.forceActiveFocus()
    }

    function back() {
        if (tabId === "home" && homePage.cancel()) return
        if (searchable && (query !== "" || searchPinned)) {
            search.text = ""
            searchPinned = false
            return
        }
        close()
    }

    // Shared by the search field and the panel; returns whether the key was used.
    function handleKey(event) {
        const k = event.key
        const ctrl = event.modifiers & Qt.ControlModifier
        grid.mouseMoved = false

        if (k === Qt.Key_Escape) { back(); return true }
        if (k === Qt.Key_Backtab || (k === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) { setTab((tab + tabs.length - 1) % tabs.length); return true }
        if (k === Qt.Key_Tab) { setTab((tab + 1) % tabs.length); return true }
        if (ctrl && k >= Qt.Key_1 && k <= Qt.Key_4) { setTab(k - Qt.Key_1); return true }

        if (tabId === "apps") {
            if (k === Qt.Key_Right) moveSelection(1)
            else if (k === Qt.Key_Left) moveSelection(-1)
            else if (k === Qt.Key_Down) moveSelection(cols)
            else if (k === Qt.Key_Up) moveSelection(-cols)
            else if (k === Qt.Key_PageDown) moveSelection(cols * 3)
            else if (k === Qt.Key_PageUp) moveSelection(-cols * 3)
            else if (k === Qt.Key_Return || k === Qt.Key_Enter) launch(picked)
            else return false
            return true
        }
        if (tabId === "home") return homePage.handleKey(event)
        if (tabId === "commands") return shellPage.handleKey(event)
        return binds.handleKey(event)
    }

    // ---- Open and close --------------------------------------------------------------------------------------


    Component.onCompleted: {
        targetScreen = focusedScreen()
        scan.running = true
        scanCommands.running = true
    }

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor
        return Quickshell.screens.find(s => s.name === mon?.name) ?? Quickshell.screens[0]
    }

    function show(which) {
        const i = tabs.findIndex(x => x.id === which)
        if (active && !leaving) {
            if (i >= 0) setTab(i)
            return
        }
        // Everything that resets between sessions already ran when the last one closed, so opening only animates.
        if (!active) {
            tab = i >= 0 ? i : homeTab
        } else if (i >= 0) {
            tab = i
        }
        const scr = focusedScreen()
        if (!active && scr !== targetScreen) {
            // A different monitor needs a new surface; give it a moment before rising.
            targetScreen = scr
            moveDelay.restart()
            return
        }
        begin()
    }

    function begin() {
        leaving = false
        active = true
        Theme.refresh()
        focusTab()
        replayIntro()
        animateTo(1)
    }

    function close() {
        if (!active || leaving) return
        if (tabId === "keybinds" && binds.touched) bump(bindCache, binds.currentId)
        leaving = true
        animateTo(0)
    }

    function toggle() {
        if (active && !leaving) close()
        else show("")
    }

    // On Hyprland's curves, like the OSD: in the way windows open, out the way they close.
    function animateTo(target) {
        tween.stop()
        tween.from = t
        tween.to = target
        tween.duration = Theme.ms(target === 1 ? 520 : 320)
        tween.easing.bezierCurve = target === 1 ? Theme.settle : Theme.leave
        tween.start()
    }

    // Contents fade in once the shape is nearly full; `from` staggers header, pages and tabs a beat apart.
    // On the way out they leave together, before the shape starts to fold.
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
            root.searchPinned = false
            // Reset for next time now, while hidden, so opening has no work to do before it animates.
            search.text = ""
            root.refresh()
            shellPage.dirty = true
            homePage.reset()
            binds.reset()
            // Pick up new executables and .bashrc edits for next time.
            scanCommands.running = true
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function open(): void { root.show("") }
        function close(): void { root.close() }
        function tab(id: string): void { root.show(id) }
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
        exclusionMode: ExclusionMode.Normal
        // While open the whole surface takes input, so a click outside the panel closes it.
        // The music card, when it's open on this screen, is cut out so both can be used at once.
        mask: Region {
            item: root.active && !root.leaving ? keyRoot : null
            Region {
                readonly property var m: root.music.open && root.music.screen === win.screen?.name ? root.music : null
                intersection: Intersection.Subtract
                // Wherever it has been dragged; older placements only gave the size, centered under the bar.
                x: m ? (m.x ?? Math.round((win.width - m.side) / 2)) : 0
                y: m ? (m.y ?? m.top) : 0
                width: m ? m.side : 0
                height: m ? m.side : 0
            }
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "app-drawer"
        WlrLayershell.keyboardFocus: root.active && !root.leaving ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Item {
            id: keyRoot
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (root.handleKey(event)) { event.accepted = true; return }
                // Typing on Home jumps to the app search with that character.
                const ch = event.text
                if (ch.length === 1 && ch >= " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    root.setTab(root.tabIndex("apps"))
                    search.text += ch
                    event.accepted = true
                }
            }

            MouseArea {
                anchors.fill: parent
                onPressed: root.close()
            }

            // Never hidden, only transparent: hiding would drop every icon texture and rebuild them on the
            // first frames of each opening, which is what made it stutter.
            Item {
                id: card
                width: root.dot + (root.cardW - root.dot) * root.mw
                height: root.dot + (root.cardH - root.dot) * root.mh
                // Fully round as a capsule, relaxing to Hyprland's own rounding as it opens.
                readonly property real rest: Math.min(root.dot / 2, Theme.rounding)
                readonly property real radius: Math.max(rest, root.dot / 2 - (root.dot / 2 - rest) * Math.min(1, root.mw))
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                // Solid the whole way (no faint tail for the blur to ghost on).
                opacity: root.active ? Math.min(1, root.t * 8) : 0
                // Starts below the edge and rises onto it; afterwards it only grows, so the bottom never lifts.
                transform: Translate { y: (1 - root.rise) * (root.dot + 24) }

                // Clicks on bare panel must not reach the close-on-outside-click backdrop.
                MouseArea { anchors.fill: parent }

                // Matches Hyprland: its rounding, translucent over compositor blur (and hyprglass where enabled).
                // The bottom is pushed past the screen edge so only the top corners are rounded.
                Rectangle {
                    width: parent.width
                    height: parent.height + card.radius + 2
                    radius: card.radius
                    color: Theme.alpha(Theme.bg, 0.6)
                    border.width: 1
                    border.color: Theme.alpha(Theme.fg, 0.07)
                }

                // Contents keep their full-size layout and are revealed by the growing shape, so nothing reflows.
                Item {
                    anchors.fill: parent
                    // Always on: switching clipping as the shape finishes restructures the scene mid-animation.
                    clip: true

                Item {
                    id: content
                    width: root.cardW - root.pad * 2
                    height: root.cardH - root.pad - Math.round(root.pad * 0.7)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(root.pad * 0.7)

                    Item {
                        id: header
                        width: parent.width
                        height: Math.round(36 * root.u)
                        opacity: root.stage(0.55)
                        transform: Translate { y: 10 * (1 - root.stage(0.5)) }

                        SearchPill {
                            id: search
                            height: parent.height
                            fullWidth: header.width
                            placeholder: root.tabs[root.tab].search
                            expanded: root.searchable && (root.searchPinned || root.query !== "")
                            hint: root.query === "" ? ""
                                : root.tabId === "apps" ? (root.picked ? root.picked.name : "")
                                : root.tabId === "commands" && shellPage.current ? shellPage.current.n : ""
                            onClicked: {
                                root.searchPinned = true
                                if (!root.searchable) root.setTab(root.tabIndex("apps"))
                                else root.focusTab()
                            }
                            // The field forwards navigation to the panel and keeps everything else as text.
                            keyHandler: event => root.handleKey(event)
                        }

                        Text {
                            id: title
                            anchors.left: parent.left
                            anchors.leftMargin: header.height + 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.tabs[root.tab].title
                            font.family: Theme.sans
                            font.pixelSize: 17
                            color: Theme.bright
                            property real fade: 1
                            opacity: fade * (1 - Math.min(1, search.open))
                            transform: Translate { id: titleShift }

                            Connections {
                                target: root
                                function onTabChanged() { titleAnim.restart() }
                            }
                            ParallelAnimation {
                                id: titleAnim
                                NumberAnimation { target: titleShift; property: "y"; from: 6; to: 0; duration: Theme.move; easing.type: Easing.OutCubic }
                                NumberAnimation { target: title; property: "fade"; from: 0; to: 1; duration: Theme.ms(220); easing.type: Easing.OutCubic }
                            }
                        }

                        // Names stay off the grid; the one under the highlight is spelled out here.
                        Text {
                            anchors.right: parent.right
                            anchors.left: title.right
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            text: root.tabId === "apps" ? (root.picked ? root.picked.name : "")
                                : root.tabId === "home" ? "Enter to run"
                                : root.tabId === "commands" ? root.shellCommands.length + " commands"
                                : "shortcuts.lua"
                            font.family: Theme.sans
                            font.pixelSize: 12
                            color: Theme.dim
                            opacity: 1 - Math.min(1, search.open)
                        }
                    }

                    Item {
                        id: pages
                        anchors.top: header.bottom
                        anchors.topMargin: Math.round(12 * root.u)
                        anchors.bottom: tabBar.top
                        anchors.bottomMargin: Math.round(10 * root.u)
                        width: parent.width
                        opacity: root.stage(0.62)

                        Page {
                            tab: "apps"
                            AppGrid {
                                id: grid
                                anchors.fill: parent
                                apps: root.apps
                                slots: root.slots
                                count: root.results.length
                                selected: root.selected
                                cols: root.cols
                                cell: root.cell
                                gap: root.gap
                                hlPad: root.hlPad
                                intro: root.gridIntro
                                emptyText: root.apps.length === 0 ? "Loading applications…" : "Nothing matches “" + root.query + "”"
                                onLaunch: app => root.launch(app)
                                onHover: slot => root.selected = slot
                            }
                        }

                        Page {
                            tab: "home"
                            HomePage {
                                id: homePage
                                anchors.fill: parent
                                counts: root.counts(homeCacheFile.text())
                                intro: root.introHome
                                onRun: (id, cmd, after) => root.runHome(id, cmd, after)
                            }
                        }

                        Page {
                            tab: "commands"
                            ShellPage {
                                id: shellPage
                                anchors.fill: parent
                                commands: root.shellCommands
                                counts: root.counts(shellCacheFile.text())
                                query: root.query
                                live: root.active && root.tabId === "commands"
                                onRun: (cmd, key, background) => root.runShell(cmd, key, background)
                            }
                        }

                        Page {
                            tab: "keybinds"
                            KeybindsPage {
                                id: binds
                                anchors.fill: parent
                                counts: root.counts(bindCacheFile.text())
                                intro: root.introBinds
                                query: root.query
                            }
                        }
                    }

                    Item {
                        id: tabBar
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        readonly property real cellW: Math.round(Math.min(96 * root.u, (content.width - 12) / root.tabs.length))
                        readonly property real gapW: 4
                        width: cellW * root.tabs.length + gapW * (root.tabs.length - 1)
                        height: Math.round(32 * root.u)
                        opacity: root.stage(0.7)
                        transform: Translate { y: 8 * (1 - root.stage(0.66)) }

                        Rectangle {
                            width: tabBar.cellW
                            height: parent.height
                            radius: 9
                            x: root.tab * (tabBar.cellW + tabBar.gapW)
                            color: Theme.alpha(Theme.accent, 0.3)
                            Behavior on x { NumberAnimation { duration: Theme.move; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
                        }

                        Repeater {
                            model: root.tabs

                            Item {
                                id: tabItem
                                required property var modelData
                                required property int index
                                readonly property bool on: root.tab === index
                                x: index * (tabBar.cellW + tabBar.gapW)
                                width: tabBar.cellW
                                height: tabBar.height

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tabItem.modelData.icon
                                        font.family: Theme.sans
                                        font.pixelSize: 13
                                        color: tabItem.on || tabArea.containsMouse ? Theme.bright : Theme.dim
                                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tabItem.modelData.label
                                        font.family: Theme.sans
                                        font.pixelSize: 11
                                        color: tabItem.on || tabArea.containsMouse ? Theme.bright : Theme.dim
                                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                                    }
                                }

                                MouseArea {
                                    id: tabArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setTab(tabItem.index)
                                }
                            }
                        }
                    }
                }
                }
            }
        }
    }

    // Pages stay alive; the current one is opaque and in place, the others wait faded to the side they lie on.
    component Page: Item {
        required property string tab
        readonly property int index: root.tabIndex(tab)
        readonly property bool on: root.tab === index
        anchors.fill: parent
        enabled: on
        // The incoming page is visible at once so it can take focus before it has faded in.
        visible: on || opacity > 0.01
        opacity: on ? 1 : 0
        property real slide: on ? 0 : (index < root.tab ? -1 : 1) * 28
        Behavior on opacity { NumberAnimation { duration: Theme.ms(220); easing.type: Easing.OutCubic } }
        Behavior on slide { NumberAnimation { duration: Theme.move; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
        transform: Translate { x: slide }
    }
}
