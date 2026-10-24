import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../common"

// The bar's menus, drawn like the settings panel: rows (Entry) in tinted groups (Group), the shared Switch and
// Slider from common. Network, Audio, Power and Tray are the pages the status chips open.
QtObject {
    // One row of a menu, styled like the settings panel's dropdown rows: a glyph or icon, a label with an
    // optional second line, and a trailing note. Active rows take the accent tint.
    component Entry: Rectangle {
        id: row

        property string glyph: ""
        property string iconSource: ""
        property string label: ""
        property string sub: ""
        property string trailing: ""
        property bool active: false
        property bool busy: false
        property bool enabledRow: true
        readonly property bool hot: area.containsMouse
        signal clicked()
        signal rightClicked()

        width: parent ? parent.width : 0
        height: sub !== "" ? 46 : 36
        radius: 8
        color: active ? Theme.alpha(Theme.accent, area.containsMouse ? 0.34 : 0.26)
            : Theme.alpha(Theme.fg, area.containsMouse && enabledRow ? 0.1 : 0)
        opacity: enabledRow ? 1 : 0.45
        Behavior on color { ColorAnimation { duration: Theme.ms(120) } }

        Item {
            id: lead
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            visible: row.glyph !== "" || row.iconSource !== ""

            Text {
                anchors.centerIn: parent
                visible: row.iconSource === ""
                text: row.glyph
                font.family: Theme.sans
                font.pixelSize: 15
                color: row.active ? Theme.accent : Theme.fg
                // A spinning glyph while something is in progress.
                RotationAnimation on rotation {
                    running: row.busy
                    from: 0
                    to: 360
                    duration: 1100
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) parent.rotation = 0
                }
            }

            IconImage {
                anchors.centerIn: parent
                visible: row.iconSource !== ""
                implicitSize: 18
                source: row.iconSource
            }
        }

        Column {
            anchors.left: lead.visible ? lead.right : parent.left
            anchors.leftMargin: lead.visible ? 10 : 12
            anchors.right: tail.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: row.label
                elide: Text.ElideRight
                font.family: Theme.sans
                font.pixelSize: 13
                color: row.active || row.hot ? Theme.bright : Theme.fg
            }
            Text {
                width: parent.width
                visible: row.sub !== ""
                text: row.sub
                elide: Text.ElideRight
                font.family: Theme.sans
                font.pixelSize: 10
                color: Theme.dim
            }
        }

        Text {
            id: tail
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.trailing
            font.family: Theme.sans
            font.pixelSize: 11
            color: row.active ? Theme.accent : Theme.dim
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: row.enabledRow
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => m.button === Qt.RightButton ? row.rightClicked() : row.clicked()
        }
    }

    // A menu's title row: an optional app icon, the title, a dim note, and anything else (a switch) on the right.
    component Header: Item {
        id: h
        property string title
        property string note
        property string icon
        default property alias trailing: tail.data
        width: parent ? parent.width : 0
        height: 26

        IconImage {
            id: appIcon
            anchors.verticalCenter: parent.verticalCenter
            visible: h.icon !== ""
            implicitSize: 18
            source: h.icon
        }
        Text {
            anchors.left: appIcon.visible ? appIcon.right : parent.left
            anchors.leftMargin: appIcon.visible ? 10 : 0
            anchors.right: noteText.left
            anchors.verticalCenter: parent.verticalCenter
            text: h.title
            elide: Text.ElideRight
            font.family: Theme.sans
            font.pixelSize: 16
            color: Theme.bright
        }
        Text {
            id: noteText
            anchors.right: tail.left
            anchors.rightMargin: tail.width > 0 ? 10 : 0
            anchors.verticalCenter: parent.verticalCenter
            text: h.note
            font.family: Theme.sans
            font.pixelSize: 10
            color: Theme.dim
        }
        Row {
            id: tail
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // A labelled group of rows, laid out like a settings panel section: a small caps title over a tinted card.
    // Rows scroll once there are more than fit in maxHeight.
    component Group: Column {
        id: sec

        property string title: ""
        property int maxHeight: 240
        property string empty: ""
        default property alias rows: list.data

        width: parent ? parent.width : 0
        spacing: 6

        Text {
            x: 4
            visible: sec.title !== ""
            text: sec.title.toUpperCase()
            font.family: Theme.sans
            font.pixelSize: 10
            font.letterSpacing: 1.6
            color: Theme.dim
        }

        Rectangle {
            width: parent.width
            // Room for the empty note when there are no rows.
            height: Math.min(sec.maxHeight, Math.max(sec.empty !== "" && list.implicitHeight < 4 ? 40 : 0, list.implicitHeight + 8))
            radius: 12
            color: Theme.alpha(Theme.fg, 0.055)

            Flickable {
                anchors.fill: parent
                anchors.margins: 4
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: list
                    width: parent.width
                    spacing: 2
                }
            }

            Text {
                anchors.centerIn: parent
                visible: sec.empty !== "" && list.implicitHeight < 4
                text: sec.empty
                font.family: Theme.sans
                font.pixelSize: 12
                color: Theme.dim
            }
        }
    }

    // Wi-Fi and Bluetooth, opened from the network chip or the connected device beside it.
    component Network: Grid {
        id: menu

        property bool open: false
        signal run(string cmd)

        readonly property bool holdOpen: wifi.holdOpen
        // Side by side when the card is wide (the one big pill), stacked otherwise.
        readonly property real colW: columns === 2 ? (width - columnSpacing) / 2 : width

        columns: width >= 600 ? 2 : 1
        columnSpacing: 22
        rowSpacing: 18

        Wifi {
            id: wifi
            width: menu.colW
            open: menu.open
            onRun: c => menu.run(c)
        }

        Bluetooth {
            width: menu.colW
            open: menu.open
        }
    }

    // Wi-Fi: the radio switch, the wired link if there is one, and nearby networks (scanned while the menu is
    // open). Click to connect or disconnect; a secured network asks for its password inline. Right-click forgets.
    // The top half of the network menu.
    component Wifi: Column {
        id: menu

        property bool open: false
        signal run(string cmd)

        spacing: 12

        readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
        readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
        readonly property var networks: wifiDev
            ? wifiDev.networks.values.filter(n => n.name !== "").slice().sort((a, b) =>
                (b.connected - a.connected) || (b.known - a.known) || (strength(b) - strength(a)))
            : []
        // The network waiting on a password, and why the last attempt failed.
        property string asking: ""
        // Typing a password keeps the menu open and takes the keyboard.
        readonly property bool holdOpen: asking !== ""
        property var failed: ({})

        Binding {
            target: menu.wifiDev
            property: "scannerEnabled"
            value: true
            when: menu.open && !!menu.wifiDev && Networking.wifiEnabled
            restoreMode: Binding.RestoreBindingOrValue
        }

        onOpenChanged: if (!open) asking = ""

        function strength(n) {
            const s = n.signalStrength ?? 0
            return s > 1 ? s / 100 : s
        }

        function glyph(n) {
            const f = strength(n)
            return f > 0.75 ? "󰤨" : f > 0.5 ? "󰤥" : f > 0.25 ? "󰤢" : "󰤟"
        }

        function secured(n) {
            return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe
        }

        function pick(n) {
            failed = Object.assign({}, failed, { [n.name]: "" })
            if (n.connected) n.disconnect()
            else if (n.known || !secured(n)) n.connect()
            else asking = asking === n.name ? "" : n.name
        }

        Header {
            title: "Wi-Fi"
            note: Networking.wifiEnabled && menu.wifiDev && menu.wifiDev.scannerEnabled ? "Scanning…" : ""
            Switch {
                checked: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        Group {
            title: "Wired"
            visible: !!menu.wired

            Entry {
                glyph: "󰈀"
                label: menu.wired ? (menu.wired.name || "Ethernet") : ""
                sub: menu.wired && menu.wired.address ? menu.wired.address : "Connected"
                trailing: "Connected"
                active: true
                onClicked: menu.run("kitty nmtui")
            }
        }

        Group {
            title: "Networks"
            maxHeight: 190
            empty: !menu.wifiDev ? "No Wi-Fi adapter" : !Networking.wifiEnabled ? "Wi-Fi is off" : "Looking for networks…"

            Repeater {
                model: Networking.wifiEnabled ? menu.networks : []

                Column {
                    id: net
                    required property var modelData
                    readonly property bool connecting: modelData.state === ConnectionState.Connecting || modelData.stateChanging
                    width: parent.width
                    spacing: 4

                    Connections {
                        target: net.modelData
                        function onConnectionFailed(reason) {
                            menu.failed = Object.assign({}, menu.failed, { [net.modelData.name]: ConnectionFailReason.toString(reason) })
                            if (!net.modelData.known && menu.secured(net.modelData)) menu.asking = net.modelData.name
                        }
                        function onConnectedChanged() { if (net.modelData.connected && menu.asking === net.modelData.name) menu.asking = "" }
                    }

                    Entry {
                        glyph: menu.glyph(net.modelData)
                        label: net.modelData.name
                        sub: {
                            const f = menu.failed[net.modelData.name]
                            if (f) return "Couldn't connect: " + f
                            if (net.connecting) return "Connecting…"
                            if (net.modelData.connected) return "Connected"
                            return [net.modelData.known ? "Saved" : "", menu.secured(net.modelData) ? "Secured" : "Open"].filter(s => s).join(" · ")
                        }
                        trailing: (menu.secured(net.modelData) ? "  " : "") + Math.round(menu.strength(net.modelData) * 100) + "%"
                        active: net.modelData.connected
                        busy: net.connecting
                        onClicked: menu.pick(net.modelData)
                        onRightClicked: if (net.modelData.known) net.modelData.forget()
                    }

                    // Password, inline under the network that needs it.
                    Rectangle {
                        visible: menu.asking === net.modelData.name
                        width: parent.width
                        height: 36
                        radius: 8
                        color: Theme.alpha(Theme.fg, 0.08)
                        border.width: 1
                        border.color: pass.activeFocus ? Theme.alpha(Theme.accent, 0.6) : "transparent"
                        onVisibleChanged: if (visible) { pass.text = ""; pass.forceActiveFocus() }

                        TextInput {
                            id: pass
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: go.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            echoMode: show.on ? TextInput.Normal : TextInput.Password
                            font.family: Theme.sans
                            font.pixelSize: 13
                            color: Theme.bright
                            selectionColor: Theme.alpha(Theme.accent, 0.5)
                            clip: true
                            onAccepted: go.connect()
                            Keys.onEscapePressed: menu.asking = ""

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: pass.text === ""
                                text: "Password"
                                font: pass.font
                                color: Theme.dim
                            }
                        }

                        Text {
                            id: show
                            property bool on: false
                            anchors.right: go.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: on ? "" : ""
                            font.family: Theme.sans
                            font.pixelSize: 12
                            color: Theme.dim
                            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: show.on = !show.on }
                        }

                        Button {
                            id: go
                            function connect() {
                                if (pass.text.length === 0) return
                                menu.failed = Object.assign({}, menu.failed, { [net.modelData.name]: "" })
                                net.modelData.connectWithPsk(pass.text)
                            }
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            height: 28
                            primary: true
                            label: "Connect"
                            onPressed: connect()
                        }
                    }
                }
            }
        }
    }

    // Bluetooth: the adapter switch, paired devices, and nearby ones (discovered while the menu is open).
    // Click connects or disconnects, pairing first when needed; right-click forgets a paired device.
    // The bottom half of the network menu.
    component Bluetooth: Column {
        id: menu

        property bool open: false

        spacing: 12

        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property bool on: !!adapter && adapter.enabled
        readonly property var all: adapter ? adapter.devices.values : []
        readonly property var paired: all.filter(d => d.paired || d.connected)
            .sort((a, b) => (b.connected - a.connected) || label(a).localeCompare(label(b)))
        // Unnamed devices only show their address, which is no use to pick from.
        readonly property var nearby: all.filter(d => !d.paired && !d.connected && d.name && d.name !== d.address.replace(/:/g, "-"))
            .sort((a, b) => label(a).localeCompare(label(b)))
        // Devices being paired so they can be connected once that finishes.
        property var pending: ({})

        Binding {
            target: menu.adapter
            property: "discovering"
            value: true
            when: menu.open && menu.on
            restoreMode: Binding.RestoreBindingOrValue
        }

        function label(d) {
            return d.name || d.deviceName || d.address
        }

        function glyph(d) {
            const i = (d.icon || "").toLowerCase()
            if (i.includes("headset") || i.includes("headphone")) return "󰋋"
            if (i.includes("audio") || i.includes("speaker")) return "󰓃"
            if (i.includes("keyboard")) return "󰌌"
            if (i.includes("mouse")) return "󰍽"
            if (i.includes("phone")) return "󰄜"
            if (i.includes("gaming") || i.includes("joystick")) return "󰊴"
            if (i.includes("computer")) return "󰌢"
            return "󰂯"
        }

        function status(d) {
            if (d.pairing) return "Pairing…"
            if (d.state === BluetoothDeviceState.Connecting) return "Connecting…"
            if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…"
            if (d.connected) return "Connected"
            return d.paired ? "Paired" : "Not paired"
        }

        function pick(d) {
            if (d.connected) d.disconnect()
            else if (d.paired) d.connect()
            else {
                pending = Object.assign({}, pending, { [d.address]: true })
                d.trusted = true
                d.pair()
            }
        }

        Header {
            title: "Bluetooth"
            note: menu.on && menu.adapter.discovering ? "Searching…" : ""
            Switch {
                checked: menu.on
                onToggled: if (menu.adapter) menu.adapter.enabled = !menu.adapter.enabled
            }
        }

        Group {
            title: "Devices"
            maxHeight: 150
            empty: !menu.adapter ? "No Bluetooth adapter" : !menu.on ? "Bluetooth is off" : "No paired devices"

            Repeater {
                model: menu.on ? menu.paired : []
                DeviceRow { owner: menu }
            }
        }

        Group {
            title: "Nearby"
            maxHeight: 130
            visible: menu.on
            empty: "Searching…"

            Repeater {
                model: menu.on ? menu.nearby : []
                DeviceRow { owner: menu }
            }
        }
    }

    // A Bluetooth device in the network menu; `owner` is the Bluetooth half it belongs to.
    component DeviceRow: Entry {
        id: dr
        property var owner
        required property var modelData
        glyph: owner.glyph(modelData)
        label: owner.label(modelData)
        sub: owner.status(modelData)
        trailing: modelData.batteryAvailable ? Math.round((modelData.battery > 1 ? modelData.battery : modelData.battery * 100)) + "%" : ""
        active: modelData.connected
        busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
        onClicked: owner.pick(modelData)
        onRightClicked: if (modelData.paired) modelData.forget()

        Connections {
            target: dr.modelData
            function onPairedChanged() {
                if (dr.modelData.paired && owner.pending[dr.modelData.address]) {
                    owner.pending = Object.assign({}, owner.pending, { [dr.modelData.address]: false })
                    dr.modelData.connect()
                }
            }
        }
    }

    // Sound: output and microphone levels, and which device each one uses.
    component Audio: Grid {
        id: menu

        property bool open: false
        signal run(string cmd)
        signal done()

        // Levels beside the devices when the card is wide (the one big pill), stacked otherwise.
        readonly property real colW: columns === 2 ? (width - columnSpacing) / 2 : width
        columns: width >= 600 ? 2 : 1
        columnSpacing: 22
        rowSpacing: 12

        readonly property var sink: Pipewire.defaultAudioSink
        readonly property var source: Pipewire.defaultAudioSource
        readonly property var devices: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
        readonly property var outputs: devices.filter(n => n.isSink)
        readonly property var inputs: devices.filter(n => !n.isSink && !(n.name || "").endsWith(".monitor"))

        PwObjectTracker { objects: menu.open ? menu.devices : [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

        function name(n) {
            return n.nickname || n.description || n.name
        }

        function volGlyph(v) {
            return v > 0.66 ? "󰕾" : v > 0.33 ? "󰖀" : "󰕿"
        }

        Column {
            width: menu.colW
            spacing: 12

            Header { title: "Sound" }

            Level {
                node: menu.sink
                device: menu.sink ? menu.name(menu.sink) : ""
                title: "Output"
                glyph: menu.volGlyph(menu.sink && menu.sink.audio ? menu.sink.audio.volume : 0)
                mutedGlyph: "󰝟"
            }

            Level {
                node: menu.source
                device: menu.source ? menu.name(menu.source) : ""
                title: "Microphone"
                glyph: "󰍬"
                mutedGlyph: "󰍭"
            }
        }

        Column {
            width: menu.colW
            spacing: 12

            Group {
                title: "Output device"
                maxHeight: 170
                empty: "No outputs"
                Repeater {
                    model: menu.outputs
                    Entry {
                        required property var modelData
                        glyph: "󰓃"
                        label: menu.name(modelData)
                        active: menu.sink === modelData
                        trailing: active ? "" : ""
                        onClicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }
            }

            Group {
                title: "Input device"
                maxHeight: 130
                visible: menu.inputs.length > 0
                Repeater {
                    model: menu.inputs
                    Entry {
                        required property var modelData
                        glyph: "󰍬"
                        label: menu.name(modelData)
                        active: menu.source === modelData
                        trailing: active ? "" : ""
                        onClicked: Pipewire.preferredDefaultAudioSource = modelData
                    }
                }
            }

            Group {
                Entry {
                    glyph: "󰕾"
                    label: "Mixer"
                    sub: "Per-app volume"
                    onClicked: { menu.run("pypr toggle music 2>/dev/null || pavucontrol"); menu.done() }
                }
            }
        }
    }

    // One volume row of the sound menu: a mute button, the level and the device it sets.
    component Level: Column {
        id: lv
        property var node
        property string title
        property string glyph
        property string mutedGlyph
        property string device
        readonly property bool ok: !!node && !!node.audio
        readonly property real vol: ok ? node.audio.volume : 0
        readonly property bool muted: ok && node.audio.muted
        width: parent.width
        spacing: 6

        Item {
            width: parent.width
            height: 16
            Text {
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                text: lv.title.toUpperCase()
                font.family: Theme.sans
                font.pixelSize: 10
                font.letterSpacing: 1.6
                color: Theme.dim
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.left: parent.horizontalCenter
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
                text: lv.ok ? lv.device : "None"
                elide: Text.ElideRight
                font.family: Theme.sans
                font.pixelSize: 10
                color: Theme.dim
            }
        }

        Rectangle {
            width: parent.width
            height: 44
            radius: 12
            color: Theme.alpha(Theme.fg, 0.055)
            opacity: lv.ok ? 1 : 0.45

            Text {
                id: muteBtn
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                text: lv.muted ? lv.mutedGlyph : lv.glyph
                font.family: Theme.sans
                font.pixelSize: 16
                color: lv.muted ? Theme.dim : muteArea.containsMouse ? Theme.accent : Theme.bright
                MouseArea {
                    id: muteArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (lv.ok) lv.node.audio.muted = !lv.node.audio.muted
                }
            }

            Slider {
                anchors.left: muteBtn.right
                anchors.leftMargin: 12
                anchors.right: pct.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                value: lv.vol
                dimmed: lv.muted
                onMoved: v => { if (lv.ok) { lv.node.audio.volume = v; if (v > 0) lv.node.audio.muted = false } }
            }

            Text {
                id: pct
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                horizontalAlignment: Text.AlignRight
                text: Math.round(lv.vol * 100) + "%"
                font.family: Theme.sans
                font.pixelSize: 12
                color: Theme.fg
            }
        }
    }

    // Session: lock and suspend at once; log out, reboot and shut down wait for a second press.
    component Power: Column {
        id: menu

        property bool open: false
        signal run(string cmd)
        signal done()

        spacing: 12

        property string armed: ""
        property string uptime: ""
        onOpenChanged: { armed = ""; if (open) up.running = true }

        Process {
            id: up
            command: ["uptime", "-p"]
            stdout: StdioCollector { onStreamFinished: menu.uptime = text.trim().replace(/^up /, "") }
        }
        Timer { id: disarm; interval: 3000; onTriggered: menu.armed = "" }

        readonly property var actions: [
            { id: "lock", glyph: "", label: "Lock", cmd: "l=~/.config/hypr/utilities/lock.sh; if [ -x \"$l\" ]; then exec \"$l\"; elif command -v hyprlock >/dev/null; then exec hyprlock; else loginctl lock-session; fi", confirm: false },
            { id: "suspend", glyph: "󰒲", label: "Suspend", cmd: "systemctl suspend", confirm: false },
            { id: "logout", glyph: "󰍃", label: "Log out", cmd: Theme.lua ? "hyprctl dispatch 'hl.dsp.exit()'" : "hyprctl dispatch exit", confirm: true },
            { id: "reboot", glyph: "󰜉", label: "Reboot", cmd: "systemctl reboot", confirm: true },
            { id: "off", glyph: "󰐥", label: "Shut down", cmd: "systemctl poweroff", confirm: true }
        ]

        function press(a) {
            if (a.confirm && armed !== a.id) { armed = a.id; disarm.restart(); return }
            armed = ""
            done()
            run(a.cmd)
        }

        Header {
            title: "Session"
            note: menu.uptime !== "" ? "Up " + menu.uptime : ""
        }

        Row {
            id: grid
            spacing: 6
            readonly property real cell: (menu.width - spacing * (menu.actions.length - 1)) / menu.actions.length

            Repeater {
                model: menu.actions

                Rectangle {
                    id: btn
                    required property var modelData
                    readonly property bool armed: menu.armed === modelData.id
                    width: grid.cell
                    height: grid.cell + 14
                    radius: 12
                    color: armed ? Theme.alpha(Theme.warn, 0.4)
                        : Theme.alpha(Theme.fg, area.containsMouse ? 0.12 : 0.055)
                    scale: area.pressed ? 0.95 : 1
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Behavior on scale { NumberAnimation { duration: Theme.ms(120) } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: btn.modelData.glyph
                            font.family: Theme.sans
                            font.pixelSize: 20
                            color: btn.armed ? Theme.bright : area.containsMouse ? Theme.accent : Theme.fg
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: btn.armed ? "Again" : btn.modelData.label
                            font.family: Theme.sans
                            font.pixelSize: 10
                            color: btn.armed ? Theme.bright : Theme.dim
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menu.press(btn.modelData)
                    }
                }
            }
        }
    }

    // A tray app's own menu, drawn like the other menus instead of as a plain popup. Submenus open in place
    // with a back row; check and radio entries show their state.
    component Tray: Column {
        id: menu

        property bool open: false
        property var item: null
        signal run(string cmd)
        signal done()

        spacing: 10

        // The submenus walked into, innermost last.
        property var stack: []
        readonly property var current: stack.length > 0 ? stack[stack.length - 1] : (item ? item.menu : null)
        onItemChanged: stack = []
        onOpenChanged: if (!open) stack = []

        QsMenuOpener {
            id: opener
            menu: menu.current
        }

        Header {
            icon: menu.item ? menu.item.icon : ""
            title: menu.item ? (menu.item.tooltipTitle || menu.item.title || menu.item.id) : ""
        }

        Group {
            maxHeight: 380
            empty: "No menu"

            Entry {
                visible: menu.stack.length > 0
                glyph: ""
                label: "Back"
                onClicked: menu.stack = menu.stack.slice(0, -1)
            }

            Repeater {
                model: opener.children

                Item {
                    id: entry
                    required property var modelData
                    width: parent.width
                    height: modelData.isSeparator ? 9 : row.height

                    Rectangle {
                        visible: entry.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 20
                        height: 1
                        color: Theme.alpha(Theme.fg, 0.08)
                    }

                    Entry {
                        id: row
                        visible: !entry.modelData.isSeparator
                        readonly property bool check: entry.modelData.buttonType !== QsMenuButtonType.None
                        readonly property bool checked: entry.modelData.checkState === Qt.Checked
                        // Some apps escape their accelerators with underscores.
                        label: (entry.modelData.text || "").replace(/_(?=[^_])/g, "")
                        iconSource: entry.modelData.icon || ""
                        glyph: check ? (checked ? (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "" : "") : (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "" : "")) : ""
                        trailing: entry.modelData.hasChildren ? "" : ""
                        enabledRow: entry.modelData.enabled
                        onClicked: {
                            if (entry.modelData.hasChildren) {
                                menu.stack = menu.stack.concat([entry.modelData])
                            } else {
                                entry.modelData.triggered()
                                menu.done()
                            }
                        }
                    }
                }
            }
        }
    }
}
