import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import "../common"
import Quickshell.Io


// One module of a pill's row, named in the style's config like a waybar module:
//   user        $USER (click: home, middle: launcher, right: settings)
//   workspaces  the workspace dots
//   media       now playing: art, track and a waveform (folds away when nothing plays)
//   date        the date, in the media's place while nothing plays
//   constdate   the date, always shown
//   timer       a running focus timer
//   clock       the time
//   tray        tray apps
//   updates     pending updates (click to update; folds away when there are none)
//   network     Wi-Fi or Ethernet, and a connected Bluetooth device
//   audio       volume
//   battery     charge, on laptops
//   power       the session menu
//   |           a divider
Item {
    id: mod

    property string name
    property var pill
    property var ctx
    // Its place in the pill's row, and whether it shows anything (folded modules don't).
    property int slot: 0
    readonly property bool present: !!loader.item && loader.item.visible !== false && (loader.item.on ?? true)

    readonly property string page: pill.opens[name] ?? ""

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: pill.pillH
    width: implicitWidth
    height: implicitHeight

    // Modules that are one thing open their page when rested on; the tray and the chips do it per chip.
    HoverHandler {
        enabled: mod.page === "workspaces" || mod.page === "island"
        onHoveredChanged: hovered ? mod.pill.rest(mod.page, null, mod) : mod.pill.unrest(mod)
    }

    // The island's modules: a click opens it, a middle click plays or pauses.
    MouseArea {
        anchors.fill: parent
        enabled: mod.page === "island"
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => {
            const p = mod.ctx.player
            if (m.button === Qt.LeftButton) mod.pill.toggle("island")
            else if (p && p.canTogglePlaying) p.togglePlaying()
        }
    }

    Loader {
        id: loader
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: ({ user: userC, workspaces: workspacesC, media: mediaC, date: dateC, constdate: constdateC, timer: timerC, clock: clockC,
            tray: trayC, updates: updatesC, network: networkC, audio: audioC, battery: batteryC, power: powerC,
            "|": dividerC })[mod.name] ?? null
    }

    component Label: Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        font.family: Theme.sans
        font.pixelSize: 12
        color: Theme.fg
    }

    // ---- Left --------------------------------------------------------------------------------------------------

    Component {
        id: userC
        Chip {
            pill: mod.pill
            text: Quickshell.env("USER")
            onClicked: b => mod.ctx.run(b === Qt.RightButton ? "~/.config/hypr/utilities/shells.sh settings"
                : b === Qt.MiddleButton ? "~/.config/hypr/utilities/shells.sh launcher"
                : "~/.config/hypr/utilities/shells.sh home")
        }
    }

    Component {
        id: workspacesC
        Item {
            implicitWidth: dots.implicitWidth + 20
            implicitHeight: mod.pill.pillH
            Workspaces.Dots {
                id: dots
                anchors.centerIn: parent
            }
        }
    }

    // ---- Middle ------------------------------------------------------------------------------------------------

    Component {
        id: mediaC
        Fold {
            on: mod.ctx.showMedia(mod.pill)

            Item {
                implicitWidth: media.implicitWidth + 20
                implicitHeight: mod.pill.pillH

                Row {
                    id: media
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    ClippingRectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: Math.min(Theme.rounding, 6)
                        color: Theme.alpha(Theme.fg, 0.14)
                        Image {
                            anchors.fill: parent
                            source: mod.ctx.player ? mod.ctx.player.trackArtUrl : ""
                            sourceSize.width: 64
                            sourceSize.height: 64
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    Label {
                        id: title
                        // Gives way first when the row runs out of room (a portrait monitor): whatever the rest
                        // of the row leaves, worked out after each layout so it never chases itself.
                        property real fit: 170
                        function refit() { if (mod && mod.pill) fit = Math.max(40, Math.min(170, mod.pill.maxW - (mod.pill.rowW - width))) }
                        Connections {
                            target: mod.pill
                            function onRowWChanged() { Qt.callLater(title.refit) }
                            function onMaxWChanged() { Qt.callLater(title.refit) }
                        }
                        width: Math.min(implicitWidth, fit)
                        text: mod.ctx.player ? [mod.ctx.player.trackTitle, mod.ctx.player.trackArtist].filter(s => !!s).join("  ·  ") : ""
                        elide: Text.ElideRight
                    }

                    Wave {
                        anchors.verticalCenter: parent.verticalCenter
                        playing: mod.ctx.playing
                    }
                }
            }
        }
    }

    Component {
        id: dateC
        Fold {
            on: !mod.ctx.showMedia(mod.pill)
            Item {
                implicitWidth: dateText.implicitWidth + 20
                implicitHeight: mod.pill.pillH
                Label {
                    id: dateText
                    x: 10
                    text: Qt.formatDate(mod.ctx.now, "ddd, MMM d")
                }
            }
        }
    }

    Component {
        id: constdateC
        Fold {
            Item {
                implicitWidth: dateText.implicitWidth + 20
                implicitHeight: mod.pill.pillH
                Label {
                    id: dateText
                    x: 10
                    text: Qt.formatDate(mod.ctx.now, "ddd, MMM d")
                }
            }
        }
    }

    Component {
        id: timerC
        Fold {
            on: mod.ctx.timer.active
            Item {
                implicitWidth: timerBox.width + 8
                implicitHeight: mod.pill.pillH
                Rectangle {
                    id: timerBox
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    height: mod.pill.pillH - 10
                    width: timerText.implicitWidth + 14
                    radius: Math.min(Theme.rounding, height / 2)
                    color: Theme.alpha(Theme.accent, mod.ctx.timer.running ? 0.3 : 0.14)
                    Text {
                        id: timerText
                        anchors.centerIn: parent
                        text: "󰔛 " + mod.ctx.timer.format(mod.ctx.timer.remaining)
                        font.family: Theme.sans
                        font.pixelSize: 11
                        color: Theme.bright
                    }
                }
            }
        }
    }

    Component {
        id: clockC
        Item {
            implicitWidth: clockText.implicitWidth + 20
            implicitHeight: mod.pill.pillH
            Text {
                id: clockText
                anchors.centerIn: parent
                text: Qt.formatTime(mod.ctx.now, "h:mm AP")
                font.family: Theme.sans
                font.pixelSize: 13
                font.bold: true
                color: Theme.bright
            }
        }
    }

    // ---- Right -------------------------------------------------------------------------------------------------

    Component {
        id: trayC
        Fold {
            on: SystemTray.items.values.length > 0

            Repeater {
                model: SystemTray.items

                Chip {
                    id: trayChip
                    required property SystemTrayItem modelData
                    pill: mod.pill
                    page: modelData.hasMenu ? "tray" : ""
                    tray: modelData
                    icon: modelData.icon
                    clickOpens: false
                    onClicked: b => {
                        const item = modelData
                        if (b === Qt.MiddleButton) item.secondaryActivate()
                        else if (b === Qt.RightButton || item.onlyMenu) { if (item.hasMenu) mod.pill.toggle("tray", item) }
                        // Spotify lives in a pypr scratchpad, like the home screen and music player open it.
                        else if (Theme.isSpotify(item)) { mod.pill.close(); Theme.openSpotify() }
                        else { mod.pill.close(); item.activate() }
                    }
                    onWheel: dir => modelData.scroll(dir * 120, false)
                }
            }
        }
    }

    Component {
        id: updatesC
        Fold {
            on: mod.ctx.updates > 0
            Chip {
                pill: mod.pill
                glyph: "󰅢"
                // Keeps its number while it folds away.
                text: mod.ctx.updates > 0 ? mod.ctx.updates : ""
                onClicked: b => { if (b === Qt.LeftButton) mod.ctx.runUpdate() }
            }
        }
    }

    Component {
        id: networkC
        Row {
            id: netRow
            readonly property var dev: Networking.devices.values.find(d => d.connected && d.type === DeviceType.Wired)
                ?? Networking.devices.values.find(d => d.connected && d.type === DeviceType.Wifi) ?? null
            readonly property var net: dev && dev.type === DeviceType.Wifi ? (dev.networks.values.find(n => n.connected) ?? null) : null
            readonly property var adapter: Bluetooth.defaultAdapter
            readonly property var paired: adapter && adapter.enabled ? adapter.devices.values.filter(d => d.connected) : []

            Chip {
                pill: mod.pill
                page: "network"
                faded: !netRow.dev
                glyph: {
                    const d = netRow.dev
                    if (!d) return Networking.wifiEnabled ? "󰤯" : "󰤮"
                    if (d.type === DeviceType.Wired) return ""
                    const s = netRow.net ? netRow.net.signalStrength : 1
                    const f = s > 1 ? s / 100 : s
                    return f > 0.75 ? "󰤨" : f > 0.5 ? "󰤥" : f > 0.25 ? "󰤢" : "󰤟"
                }
                text: netRow.net ? netRow.net.name : ""
                maxText: 100
                onClicked: b => { if (b === Qt.RightButton) mod.ctx.run("kitty nmtui") }
            }

            // Only while a device is connected: its name, nothing more.
            Fold {
                on: netRow.paired.length > 0
                Chip {
                    pill: mod.pill
                    page: "network"
                    glyph: "󰂱"
                    text: netRow.paired.length > 1 ? netRow.paired.length + " devices"
                        : netRow.paired.length === 1 ? (netRow.paired[0].name || "") : ""
                    maxText: 100
                    onClicked: b => { if (b === Qt.RightButton) mod.ctx.run("blueman-manager") }
                }
            }
        }
    }

    Component {
        id: audioC
        Chip {
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
            readonly property bool muted: !!sink && !!sink.audio && sink.audio.muted
            PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

            pill: mod.pill
            page: "audio"
            visible: !!sink
            faded: muted
            glyph: muted ? "󰝟" : volume > 0.66 ? "󰕾" : volume > 0.33 ? "󰖀" : "󰕿"
            text: Math.round(volume * 100) + "%"
            widest: "100%"
            onClicked: b => {
                if (b === Qt.MiddleButton) { if (sink && sink.audio) sink.audio.muted = !muted }
                else if (b === Qt.RightButton) mod.ctx.run("pavucontrol")
            }
            onWheel: dir => { if (sink && sink.audio) sink.audio.volume = Math.max(0, Math.min(1, volume + dir * 0.05)) }
        }
    }

    Component {
        id: batteryC
        Fold {
            id: bat
            readonly property var dev: UPower.displayDevice
            readonly property bool present: !!dev && dev.isLaptopBattery && dev.isPresent
            readonly property real charge: present ? (dev.percentage > 1 ? dev.percentage / 100 : dev.percentage) : 0
            readonly property bool charging: present && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)
            on: present

            Chip {
                pill: mod.pill
                glyph: bat.charging ? "󰂄" : ["󰁻", "󰁼", "󰁾", "󰂀", "󰂂", "󰁹"][Math.min(5, Math.floor(bat.charge * 6))]
                glyphColor: !bat.charging && bat.charge < 0.2 ? Theme.warn : Theme.bright
                text: Math.round(bat.charge * 100) + "%"
                widest: "100%"
            }
        }
    }

    Component {
        id: powerC
        Chip {
            pill: mod.pill
            page: "power"
            glyph: ""
            glyphColor: lit ? Theme.warn : Theme.bright
        }
    }

    Component {
        id: dividerC
        Fold {
            on: mod.pill.dividerOn(mod.slot)
            Item {
                implicitWidth: 9
                implicitHeight: mod.pill.pillH
                Rectangle {
                    anchors.centerIn: parent
                    width: 1
                    height: 14
                    color: Theme.alpha(Theme.fg, 0.12)
                }
            }
        }
    }

    // ---- Pieces -----------------------------------------------------------------------------------------------

    // A glyph (or tray icon) with an optional label, in a pill's row. Tinted while the page it opens is showing.
    component Chip: Item {
        id: chip

        property var pill
        // The pill page resting on it opens ("" for none), and for the tray, whose.
        property string page: ""
        property var tray: null
        property string glyph: ""
        property string icon: ""
        property string text: ""
        property real maxText: 120
        // The widest the text gets ("100%"), so a number gaining a digit doesn't stretch the pill.
        property string widest: ""
        property bool faded: false
        // A left click opens or closes its page; off where the click does something else.
        property bool clickOpens: true
        readonly property bool lit: page !== "" && pill.open && pill.shownPage === page && (page !== "tray" || pill.shownTray === tray)
        property color glyphColor: lit ? Theme.accent : Theme.bright
        signal clicked(int button)
        signal wheel(int dir)

        implicitWidth: bg.width + 2
        implicitHeight: pill.pillH
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Rectangle {
            id: bg
            anchors.centerIn: parent
            height: chip.pill.pillH - 8
            width: Math.max(height, row.implicitWidth + 14)
            radius: chip.pill.radius(height)
            color: chip.lit ? Theme.alpha(Theme.accent, 0.26) : Theme.alpha(Theme.fg, area.containsMouse ? 0.1 : 0)
            Behavior on color { ColorAnimation { duration: Theme.fast } }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 5
                opacity: chip.faded ? 0.5 : 1

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: chip.icon !== ""
                    implicitSize: 15
                    source: chip.icon
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: chip.glyph !== ""
                    // A fixed slot, so glyphs of different widths (volume, signal, battery) never shift the pill.
                    width: Math.max(implicitWidth, 15)
                    horizontalAlignment: Text.AlignRight
                    text: chip.glyph
                    font.family: Theme.sans
                    font.pixelSize: 14
                    color: chip.glyphColor
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }
                Text {
                    id: label
                    anchors.verticalCenter: parent.verticalCenter
                    visible: chip.text !== ""
                    width: Math.min(Math.max(implicitWidth, widestText.width), chip.maxText)
                    TextMetrics { id: widestText; font: label.font; text: chip.widest }
                    text: chip.text
                    elide: Text.ElideRight
                    font.family: Theme.sans
                    font.pixelSize: 12
                    color: chip.lit || area.containsMouse ? Theme.bright : Theme.fg
                }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onContainsMouseChanged: {
                if (chip.page === "") return
                if (containsMouse) chip.pill.rest(chip.page, chip.tray, chip)
                else chip.pill.unrest(chip)
            }
            onClicked: m => {
                if (m.button === Qt.LeftButton && chip.clickOpens && chip.page !== "") chip.pill.toggle(chip.page, chip.tray)
                chip.clicked(m.button)
            }
            onWheel: w => chip.wheel(w.angleDelta.y > 0 ? 1 : -1)
        }
    }

    // Something in a pill's row that can come and go (the update count, a Bluetooth device, the media): it fades
    // while its width folds to nothing, so the pill around it shrinks smoothly instead of jumping.
    component Fold: Item {
        id: fold

        property bool on: true
        default property alias content: inner.data

        property real f: on ? 1 : 0
        Behavior on f { NumberAnimation { duration: Theme.move; easing.type: Easing.BezierSpline; easing.bezierCurve: fold.on ? Theme.settle : Theme.leave } }
        // Its contents can empty the moment it starts folding (a player quitting), so it folds from its last width.
        property real full: 0
        readonly property real live: inner.implicitWidth
        onLiveChanged: if (on && live > 0) full = live
        onOnChanged: if (on) full = live

        implicitWidth: (on ? live : full) * f
        implicitHeight: inner.implicitHeight
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        clip: true
        opacity: f
        visible: f > 0

        Row {
            id: inner
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    // This is the visualizer
    component Wave: Row {
        id: wave
        property bool playing: false
        property var levels: []
        readonly property int bars: 10

        spacing: 2


        Process {
            running: wave.playing

            command: [
                "cava",
                "-p",
                decodeURIComponent(
                    Qt.resolvedUrl("../music/cava.conf")
                        .toString()
                        .replace(/^file:\/\//, "")
                )
            ]

            stdout: SplitParser {
                onRead: line => {
                    const parts = line.trim().split(";")

                    if (parts.length < wave.bars)
                        return

                    const out = new Array(wave.bars)

                    for (let i = 0; i < wave.bars; i++) {
                        out[i] = Math.max(
                            0,
                            Math.min(1, (parseInt(parts[i]) || 0) / 1000)
                        )
                    }

                    wave.levels = out
                }
            }

            onRunningChanged: {
                if (!running)
                    wave.levels = []
            }
        }


        Repeater {
            model: wave.bars
            
            Rectangle {
                required property int index

                readonly property real level:
                    wave.playing ? (wave.levels[index] || 0) : 0

                // Quantize to even pixel heights to prevent alternating 1px changes.
                readonly property real targetHeight:
                    Math.max(4, Math.round((3 + level * 12) / 2) * 2)

                anchors.verticalCenter: parent.verticalCenter
                width: 2.5
                height: targetHeight
                radius: 1.25

                color: Theme.along(
                    Theme.spectrum,
                    index / (wave.bars - 1)
                )

                opacity: wave.playing ? 0.35 + 0.65 * level : 0.45

                Behavior on height {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }
        }
    }
}
