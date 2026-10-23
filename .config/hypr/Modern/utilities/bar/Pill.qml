import QtQuick
import "../common"

// One pill of the bar: a row of modules (Module.qml) that grows into a card showing the page of whichever
// module the pointer rests on. The row stays where it is, at the top of the card, so every module on the pill
// stays in reach: gliding to another one reshapes the card into its page without closing it, the old page
// fading out as the new one settles in. Leaving the card closes it. It opens the way Hyprland's windows open
// and closes the way they close, and keeps its corners while it grows.
Item {
    id: self

    property var ctx
    property var screen
    property var modules: []
    // The edge that stays put as the card grows: "left", "right" or "center".
    property string align: "center"
    // How wide the card (and its row) may grow without reaching a neighbouring pill.
    property real maxW: 10000
    // Another pill is opening: get out of its way quickly.
    property bool hurry: false

    // From the bar style: height, corners ("round" is Hyprland's rounding, or "capsule", "square"), and whether
    // it draws its background while closed (not when the style has none, or one strip behind everything).
    readonly property real pillH: ctx.pillH
    readonly property bool filled: ctx.look.background && !ctx.look.strip
    function radius(h) {
        const shape = ctx.look.shape
        return shape === "capsule" ? h / 2 : shape === "square" ? 0 : Math.min(Theme.rounding, h / 2)
    }

    // ---- Pages ------------------------------------------------------------------------------------------------

    // What each module opens. Modules missing here open nothing.
    readonly property var opens: ({ workspaces: "workspaces", media: "island", date: "island", timer: "island",
        clock: "island", tray: "tray", network: "network", audio: "audio", power: "power" })
    function has(page) {
        return modules.some(m => opens[m] === page)
    }

    // A divider only shows with something on both sides of it, so an empty tray (or any module that folds
    // away) takes its divider with it.
    function dividerOn(i) {
        const showing = j => { const m = moduleList.count > j ? moduleList.itemAt(j) : null; return !!m && m.name !== "|" && m.present }
        let before = false, after = false
        for (let j = i - 1; j >= 0 && modules[j] !== "|"; j--) before = before || showing(j)
        for (let j = i + 1; j < modules.length && modules[j] !== "|"; j++) after = after || showing(j)
        return before && after
    }
    readonly property var widths: ({ workspaces: 600, island: 540, network: 350, audio: 340, power: 330, tray: 290 })
    // The widest each page is laid out; in a card wider than that (the one big pill) it sits centred.
    readonly property var widest: ({ workspaces: 900, island: 620, network: 720, audio: 720, power: 420, tray: 360 })
    readonly property int pad: 16

    // The page asked for ("" closed) and, for the tray, whose. The page on screen is the front slot's.
    property string page: ""
    property var tray: null
    readonly property bool open: page !== ""
    readonly property string shownPage: front.page
    readonly property var shownTray: front.tray
    // The island's tab, kept while the card stays open.
    property string tab: ""

    function show(p, t) {
        closeDelay.stop()
        openDelay.stop()
        if (p === "") { close(); return }
        if (!open && self.t === 0 && ctx.musicInTheWay(self, p)) {
            // The music player sits where the card opens: it folds away first, and drops back in once closed.
            pending = p
            pendingTray = t ?? null
            tucked = true
            ctx.musicCall("tuck")
            tuckWait.restart()
            return
        }
        place(p, t ?? null)
    }

    function place(p, t) {
        page = p
        tray = t
        if (front.page === p && front.tray === t) return
        if (self.t > 0) {
            // Open already: the other slot takes the new page and fades in over the old one.
            back.page = p
            back.tray = t
            frontIsA = !frontIsA
        } else {
            front.page = p
            front.tray = t
        }
    }

    function close() {
        openDelay.stop()
        closeDelay.stop()
        tuckWait.stop()
        page = ""
    }

    function toggle(p, t) {
        if (open && page === p && (p !== "tray" || tray === t)) close()
        else show(p, t)
    }

    // ---- Hover ------------------------------------------------------------------------------------------------

    // The pointer rests on a module: its page opens after a moment, or at once while the card is already open.
    // `from` is the module or chip resting, so leaving one only cancels its own wait: moving straight onto the
    // next can start that one's before the first one's leave arrives.
    property string pending: ""
    property var pendingTray: null
    property var pendingFrom: null
    function rest(p, t, from) {
        closeDelay.stop()
        pendingFrom = from ?? null
        if (open) show(p, t)
        else { pending = p; pendingTray = t ?? null; openDelay.restart() }
    }
    function unrest(from) {
        if (pendingFrom === (from ?? null)) openDelay.stop()
    }

    readonly property bool hovered: hover.hovered
    // The open page wants to stay (a password being typed) and needs the keyboard.
    readonly property bool holdOpen: open && !!front.item && !!front.item.holdOpen

    onHoveredChanged: {
        if (hovered) closeDelay.stop()
        else { openDelay.stop(); if (open && !holdOpen) closeDelay.restart() }
    }
    onHoldOpenChanged: if (!holdOpen && !hovered && open) closeDelay.restart()

    Timer { id: openDelay; interval: 140; onTriggered: self.show(self.pending, self.pendingTray) }
    Timer { id: closeDelay; interval: 90; onTriggered: if (!self.holdOpen) self.page = "" }

    // Whether this pill folded the music player away, and the wait for it to finish folding.
    property bool tucked: false
    // The music player changed under the open card (its own keybind, say): when it opens or comes back on its
    // own, the card steps aside rather than overlap it, and the media shows where it really is.
    property bool musicWasOpen: false
    property bool musicWasTucked: false
    Connections {
        target: self.ctx
        function onMusicChanged() {
            const m = self.ctx.music
            const opened = !!m.open && !self.musicWasOpen
            const cameBack = !!m.open && !m.tucked && self.musicWasTucked && self.tucked
            self.musicWasOpen = !!m.open
            self.musicWasTucked = !!m.tucked
            if (!m.open) self.tucked = false
            if ((opened || cameBack) && self.open && self.screen && m.screen === self.screen.name) { self.tucked = false; self.close() }
        }
    }
    Timer { id: tuckWait; interval: Theme.ms(340); onTriggered: self.place(self.pending, self.pendingTray) }

    // ---- Size -------------------------------------------------------------------------------------------------

    // Whole pixels throughout, so the 1px border stays crisp instead of straddling two rows of pixels.
    readonly property real rowW: Math.ceil(row.implicitWidth) + 8
    readonly property real targetW: Math.max(rowW, Math.min(maxW, widths[shownPage] ?? 340))
    property real bodyW: targetW
    property real bodyH: front.item ? Math.ceil(front.item.implicitHeight) + 6 + pad : 0
    Behavior on bodyW { enabled: self.t === 1; NumberAnimation { duration: Theme.move; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }
    Behavior on bodyH { enabled: self.t === 1; NumberAnimation { duration: Theme.move; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

    // 0 closed, 1 open.
    property real t: open ? 1 : 0
    Behavior on t {
        NumberAnimation {
            duration: self.hurry && !self.open ? Theme.fast : Theme.move
            easing.type: Easing.BezierSpline
            easing.bezierCurve: self.open ? Theme.settle : Theme.leave
        }
    }
    onTChanged: if (t === 0 && !open) {
        a.page = ""
        a.tray = null
        b.page = ""
        b.tray = null
        tab = ""
        if (tucked) { tucked = false; ctx.musicCall("untuck") }
    }

    y: ctx.edge
    width: rowW
    height: pillH
    visible: modules.length > 0
    z: open ? 2 : t > 0 ? 1 : 0

    // The grown card, for the window's input mask.
    readonly property alias card: card

    // Two slots take turns showing pages, so the one leaving can fade while the next arrives.
    property bool frontIsA: true
    readonly property Item front: frontIsA ? a : b
    readonly property Item back: frontIsA ? b : a

    Item {
        id: card
        // A centred card grows a pixel on each side at a time, so both edges move together instead of taking
        // turns (which made it shimmy by half a pixel as it opened).
        readonly property real grow: (self.bodyW - self.rowW) * self.t
        readonly property real w: self.rowW + (self.align === "center" ? 2 * Math.round(grow / 2) : Math.round(grow))
        x: self.align === "left" ? 0 : self.align === "right" ? self.rowW - w : (self.rowW - w) / 2
        width: w
        height: Math.round(self.pillH + self.bodyH * self.t)

        HoverHandler { id: hover }
        // Takes the hover over whatever the card has grown across.
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            anchors.fill: parent
            radius: self.radius(self.pillH)
            color: Theme.alpha(Theme.bg, 0.6 * (self.filled ? 1 : self.t))
            border.width: 1
            border.color: Theme.alpha(Theme.fg, 0.07 * (self.filled ? 1 : self.t))
        }

        // The pages, laid out at full size and uncovered by the growing card from its fixed edge.
        Item {
            y: self.pillH
            width: parent.width
            height: parent.height - self.pillH
            clip: true
            visible: self.t > 0

            Slot { id: a; front: self.frontIsA }
            Slot { id: b; front: !self.frontIsA }
        }

        Row {
            id: row
            // Pinned to the pill, not the card, so it never moves while the card grows around it.
            x: 4 - card.x
            height: self.pillH

            Repeater {
                id: moduleList
                model: self.modules
                Module {
                    required property string modelData
                    required property int index
                    slot: index
                    name: modelData
                    pill: self
                    ctx: self.ctx
                }
            }
        }
    }

    component Slot: Loader {
        id: slot
        property string page: ""
        property var tray: null
        property bool front: false
        // 1 in front, 0 behind: the arriving page fades in and settles the last few pixels into place.
        property real f: front ? 1 : 0
        Behavior on f { NumberAnimation { duration: Theme.move; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.settle } }

        readonly property real room: self.targetW - self.pad * 2
        x: Math.round(self.align === "left" ? 0 : self.align === "right" ? card.width - self.bodyW : (card.width - self.bodyW) / 2)
            + self.pad + Math.round((room - width) / 2)
        y: 6
        width: Math.min(room, self.widest[page] ?? room)
        opacity: Math.max(0, self.t * 2 - 1) * f
        visible: opacity > 0
        z: front ? 1 : 0
        transform: Translate { y: (1 - slot.f) * 8 }
        active: page !== ""
        sourceComponent: ({ workspaces: workspacesC, island: islandC, network: networkC, audio: audioC, power: powerC, tray: trayC })[page] ?? null
    }

    Component { id: workspacesC; Workspaces.Page { expose: self.ctx.expose; screen: self.screen; onPicked: self.close(); onOverview: self.ctx.toggleOverview() } }
    Component { id: islandC; Island { ctx: self.ctx; pill: self } }
    Component { id: networkC; Menus.Network { open: self.open; onRun: c => self.ctx.run(c) } }
    Component { id: audioC; Menus.Audio { open: self.open; onRun: c => self.ctx.run(c); onDone: self.close() } }
    Component { id: powerC; Menus.Power { open: self.open; onRun: c => self.ctx.run(c); onDone: self.close() } }
    // Each slot keeps its own tray app, so the one fading out still shows its menu.
    Component { id: trayC; Menus.Tray { open: self.open; item: parent ? parent.tray : null; onRun: c => self.ctx.run(c); onDone: self.close() } }
}
