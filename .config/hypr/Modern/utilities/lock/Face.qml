import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

// One monitor's lock screen. The monitor the lock came up on gets the controls; the others get the clock.
// Portrait monitors stack everything down the middle.
Item {
    id: face

    property string screenName
    readonly property bool portrait: height > width
    // One layout unit per monitor, as the home screen sizes it: against a 1600x900 landscape or 760x1350 portrait.
    readonly property real u: portrait
        ? Math.max(0.6, Math.min(width / 760, height / 1350))
        : Math.max(0.6, Math.min(width / 1600, height / 900))

    readonly property bool main: screenName === (Lock.lockedOn || (Quickshell.screens[0] || {}).name)
    readonly property bool awake: !Lock.idle
    readonly property real margin: 32 * u

    // Preview windows have no handoff layers to fade into, so they fade themselves.
    opacity: Lock.preview ? Lock.fade : 1

    // ---- Backdrop: the desktop as it was blurs away into the wallpaper ---------------------------------------

    Rectangle { anchors.fill: parent; color: "black" }

    // The frame is drawn sharp, then a blurred copy and the wallpaper crossfade over it while it all pushes in
    // a little. Only opacity and scale animate, so it stays smooth on every monitor.
    Item {
        anchors.fill: parent
        scale: 1 + 0.035 * Lock.t

        Image {
            id: shot
            anchors.fill: parent
            source: face.screenName ? "file://" + Lock.shots + "/" + face.screenName + ".ppm" : ""
            fillMode: Image.PreserveAspectCrop
            cache: false
            // Loaded before the first frame, so the lock never flashes black over the desktop.
            asynchronous: false
        }
        // Never quite 0: Qt skips invisible items, which would push the blur's first render into the animation.
        MultiEffect {
            anchors.fill: parent
            source: shot
            visible: shot.status === Image.Ready
            opacity: Math.max(0.001, Math.min(1, Lock.t * 2.2))
            blurEnabled: true
            blurMax: 64
            blur: 1
            autoPaddingEnabled: false
        }
    }
    Backdrop {
        anchors.fill: parent
        amount: Lock.t
        opacity: Math.max(0.001, shot.status === Image.Ready ? Math.min(1, (Lock.t - 0.2) * 1.8) : 1)
    }

    // ---- Input --------------------------------------------------------------------------------------------

    // Movement wakes it; a click on empty space closes the menu and gives the keyboard back to the password.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: Lock.poke()
        onClicked: { Lock.menuOpen = false; input.forceActiveFocus() }
    }

    // Every monitor has one, so typing works wherever the keyboard focus is; only the main one is drawn.
    TextInput {
        id: input
        width: 0
        height: 0
        opacity: 0
        focus: true
        echoMode: TextInput.Password
        text: Lock.password
        onTextEdited: { Lock.password = text; Lock.failed = false; Lock.poke() }
        onAccepted: Lock.submit()
        Keys.onPressed: event => {
            Lock.poke()
            Lock.checkCaps()
            if (event.key === Qt.Key_Escape) {
                if (Lock.menuOpen) Lock.menuOpen = false
                else if (Lock.preview && Lock.password === "") Lock.leave()
                else Lock.password = ""
                event.accepted = true
            }
        }
        Component.onCompleted: forceActiveFocus()
        Connections {
            target: Lock
            function onMenuOpenChanged() { if (!Lock.menuOpen) input.forceActiveFocus() }
        }
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // ---- Top left: hello -----------------------------------------------------------------------------------

    Reveal {
        x: face.margin
        y: face.margin
        delay: 0.1
        on: face.main && Lock.cfg.greeter && face.awake
        u: face.u
        Text {
            text: "Hello, <b>" + Lock.user + "</b>"
            textFormat: Text.StyledText
            font.family: Lock.sans
            font.pixelSize: 22 * face.u
            color: "#ffffff"
        }
    }

    // ---- Center: clock, date, password -------------------------------------------------------------------

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        // A little high, and further up on portrait where the music card stacks below.
        anchors.verticalCenterOffset: (face.main && face.portrait ? -140 : -30) * face.u

        Reveal {
            anchors.horizontalCenter: parent.horizontalCenter
            delay: 0.02
            on: Lock.cfg.clock
            u: face.u

            Column {
                Row {
                    id: clockRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property real size: 150 * face.u
                    // 12-hour like the bar and the old hyprlock.
                    readonly property string hh: String(clock.hours % 12 || 12).padStart(2, "0")
                    readonly property string mm: String(clock.minutes).padStart(2, "0")

                    Digit { value: clockRow.hh[0]; size: clockRow.size }
                    Digit { value: clockRow.hh[1]; size: clockRow.size }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -clockRow.size * 0.06
                        text: ":"
                        font.family: Lock.sans
                        font.pixelSize: clockRow.size * 0.9
                        font.weight: Font.Light
                        color: Lock.accent
                    }
                    Digit { value: clockRow.mm[0]; size: clockRow.size }
                    Digit { value: clockRow.mm[1]; size: clockRow.size }
                    // Seconds, small in the accent, sitting on the minutes' baseline.
                    Row {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: clockRow.size * 0.2
                        leftPadding: 10 * face.u
                        readonly property string ss: String(clock.seconds).padStart(2, "0")
                        Digit { value: parent.ss[0]; size: clockRow.size * 0.26; color: Lock.accent; weight: Font.Normal }
                        Digit { value: parent.ss[1]; size: clockRow.size * 0.26; color: Lock.accent; weight: Font.Normal }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(clock.date, "dddd, d MMMM")
                    font.family: Lock.sans
                    font.pixelSize: 24 * face.u
                    color: "#ccffffff"
                }
            }
        }

        Item { width: 1; height: (face.main ? 56 : 0) * face.u }

        // Just a lock until you type; then it widens, one dot at a time.
        Reveal {
            anchors.horizontalCenter: parent.horizontalCenter
            delay: 0.16
            on: face.main && (face.awake || Lock.password !== "")
            u: face.u

            Item {
                id: field
                readonly property real h: 54 * face.u
                readonly property bool typing: Lock.password !== ""
                width: typing ? dots.width + h + 22 * face.u : h
                height: h
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Lock.settle } }

                transform: Translate { id: shakeX }
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: shakeX; property: "x"; to: 14 * face.u; duration: 50; easing.type: Easing.OutQuad }
                    NumberAnimation { target: shakeX; property: "x"; to: -11 * face.u; duration: 90; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: shakeX; property: "x"; to: 7 * face.u; duration: 80; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: shakeX; property: "x"; to: -3 * face.u; duration: 70; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60; easing.type: Easing.OutQuad }
                }
                Connections {
                    target: Lock
                    function onRejected() { shake.restart() }
                }

                Card {
                    anchors.fill: parent
                    radius: Lock.corner(field.h, face.u)
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Lock.corner(field.h, face.u)
                    color: "transparent"
                    border.width: 1.5 * face.u
                    border.color: Lock.failed ? Lock.warn : Lock.accent
                    opacity: Lock.failed ? 1 : field.typing ? 0.5 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }
                }

                Text {
                    x: (field.h - width) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    font.family: Lock.sans
                    font.pixelSize: 19 * face.u
                    color: Lock.failed ? Lock.warn : field.typing ? Lock.accent : "#ffffff"
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Row {
                    id: dots
                    x: field.h - 4 * face.u
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * face.u
                    Repeater {
                        model: Math.min(Lock.password.length, 24)
                        Rectangle {
                            id: dot
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10 * face.u
                            height: width
                            radius: width / 2
                            color: Lock.accent
                            scale: 0
                            Component.onCompleted: pop.start()
                            NumberAnimation on scale { id: pop; running: false; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                            // While the password is checked the dots ripple.
                            SequentialAnimation on opacity {
                                running: Lock.checking
                                loops: Animation.Infinite
                                PauseAnimation { duration: dot.index * 60 }
                                NumberAnimation { to: 0.25; duration: 300; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 300; easing.type: Easing.InOutSine }
                                onRunningChanged: if (!running) dot.opacity = 1
                            }
                        }
                    }
                }
            }
        }

        Reveal {
            anchors.horizontalCenter: parent.horizontalCenter
            delay: 0.2
            on: face.main && Lock.capsLock
            u: face.u

            Item {
                width: capsText.implicitWidth
                height: capsText.implicitHeight + 16 * face.u
                Text {
                    id: capsText
                    y: 16 * face.u
                    text: "\u{f0a5b}  Caps Lock"
                    font.family: Lock.sans
                    font.pixelSize: 13 * face.u
                    color: Lock.warn
                }
            }
        }
    }

    // ---- Music: bottom right, or bottom center on portrait ------------------------------------------------

    Reveal {
        x: face.portrait ? (face.width - width) / 2 : face.width - width - face.margin
        y: face.height - height - face.margin
        delay: 0.24
        on: face.main && Lock.cfg.music && !!Lock.player && face.awake
        u: face.u

        Item {
            id: card
            readonly property var p: Lock.player
            width: 400 * face.u
            height: 156 * face.u

            // Track changes fade the text through.
            property string title: p ? p.trackTitle || "Unknown" : ""
            property string artist: p ? p.trackArtist || "" : ""
            property string shownTitle: title
            property string shownArtist: artist
            onTitleChanged: swap.restart()
            onArtistChanged: swap.restart()
            SequentialAnimation {
                id: swap
                NumberAnimation { target: info; property: "opacity"; to: 0; duration: 160 }
                ScriptAction { script: { card.shownTitle = card.title; card.shownArtist = card.artist } }
                NumberAnimation { target: info; property: "opacity"; to: 1; duration: 320; easing.type: Easing.OutCubic }
            }

            Card { anchors.fill: parent }

            ClippingRectangle {
                id: art
                x: 18 * face.u
                anchors.verticalCenter: parent.verticalCenter
                width: 120 * face.u
                height: width
                radius: Lock.corner(width, face.u)
                color: Lock.alpha(Lock.accent, 0.12)

                Text {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    text: ""
                    font.family: Lock.sans
                    font.pixelSize: 40 * face.u
                    color: Lock.accent
                }
                Image {
                    id: cover
                    anchors.fill: parent
                    source: card.p ? card.p.trackArtUrl || "" : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(256, 256)
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 400 } }
                }
            }

            Column {
                id: info
                anchors.left: art.right
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 18 * face.u
                anchors.rightMargin: 18 * face.u
                spacing: 3 * face.u

                // As tall as the visualizer's tallest bar, so the text below never moves with the music.
                Row {
                    height: 16 * face.u
                    spacing: 8 * face.u
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Now Playing"
                        font.family: Lock.sans
                        font.pixelSize: 12 * face.u
                        color: "#80ffffff"
                    }
                    Wave {
                        anchors.verticalCenter: parent.verticalCenter
                        u: face.u
                        // One cava, on the monitor that shows the card.
                        playing: face.main && Lock.cfg.music && !!card.p && card.p.isPlaying && Lock.t > 0 && !Lock.leaving
                    }
                }
                Text {
                    width: parent.width
                    text: card.shownTitle
                    elide: Text.ElideRight
                    font.family: Lock.sans
                    font.pixelSize: 17 * face.u
                    color: "#ffffff"
                }
                Text {
                    width: parent.width
                    text: card.shownArtist
                    elide: Text.ElideRight
                    font.family: Lock.sans
                    font.pixelSize: 13 * face.u
                    color: "#99ffffff"
                }

                Item { width: 1; height: 6 * face.u }

                Rectangle {
                    width: parent.width
                    height: 3 * face.u
                    radius: height / 2
                    color: Lock.alpha(Lock.fg, 0.15)
                    visible: !!card.p && card.p.lengthSupported && card.p.length > 0
                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        color: Lock.accent
                        width: card.p && card.p.length > 0 ? parent.width * Math.min(1, card.p.position / card.p.length) : 0
                        Behavior on width { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
                    }
                }

                Item { width: 1; height: 4 * face.u }

                Row {
                    spacing: 8 * face.u
                    RoundButton {
                        u: face.u; size: 34 * face.u; glyph: ""
                        opacity: card.p && card.p.canGoPrevious ? 1 : 0.4
                        onClicked: if (card.p && card.p.canGoPrevious) card.p.previous()
                    }
                    RoundButton {
                        u: face.u; size: 34 * face.u; filled: true
                        glyph: card.p && card.p.isPlaying ? "" : ""
                        onClicked: if (card.p && card.p.canTogglePlaying) card.p.togglePlaying()
                    }
                    RoundButton {
                        u: face.u; size: 34 * face.u; glyph: ""
                        opacity: card.p && card.p.canGoNext ? 1 : 0.4
                        onClicked: if (card.p && card.p.canGoNext) card.p.next()
                    }
                }
            }
        }
    }

    // ---- Top right: battery and power ---------------------------------------------------------------------

    Reveal {
        x: face.width - width - face.margin
        y: face.margin
        delay: 0.28
        on: face.main && face.awake && ((Lock.cfg.battery && Lock.hasBattery) || Lock.cfg.power)
        u: face.u

        Row {
            spacing: 8 * face.u

            Item {
                visible: Lock.cfg.battery && Lock.hasBattery
                width: batText.implicitWidth + 30 * face.u
                height: 40 * face.u
                Card { anchors.fill: parent; radius: Lock.corner(parent.height, face.u) }
                Text {
                    id: batText
                    anchors.centerIn: parent
                    readonly property bool low: !Lock.charging && Lock.charge < 0.2
                    text: (Lock.charging ? "\u{f0084}" : ["\u{f007b}", "\u{f007c}", "\u{f007e}", "\u{f0080}", "\u{f0082}", "\u{f0079}"][Math.min(5, Math.floor(Lock.charge * 6))])
                        + "  " + Math.round(Lock.charge * 100) + "%"
                    font.family: Lock.sans
                    font.pixelSize: 13 * face.u
                    color: low ? Lock.warn : "#ffffff"
                }
            }

            Repeater {
                model: Lock.cfg.power ? [
                    { glyph: "\u{f04b2}", cmd: "systemctl suspend", confirm: false },
                    { glyph: "\u{f0709}", cmd: "systemctl reboot", confirm: true },
                    { glyph: "\u{f0425}", cmd: "systemctl poweroff", confirm: true }
                ] : []
                // Reboot and power off ask for a second press.
                RoundButton {
                    id: pb
                    required property var modelData
                    property bool armedNow: false
                    u: face.u
                    size: 40 * face.u
                    glyph: modelData.glyph
                    armed: armedNow
                    Timer { id: disarm; interval: 3000; onTriggered: pb.armedNow = false }
                    onClicked: {
                        if (modelData.confirm && !armedNow) { armedNow = true; disarm.restart(); return }
                        armedNow = false
                        if (!Lock.preview) Quickshell.execDetached(["sh", "-c", modelData.cmd])
                    }
                }
            }
        }
    }

    // ---- Bottom left: the settings gear and its menu ------------------------------------------------------

    Reveal {
        id: gearReveal
        x: face.margin
        y: face.height - height - face.margin
        delay: 0.3
        on: face.main && (face.awake || Lock.menuOpen)
        u: face.u

        RoundButton {
            u: face.u
            size: 40 * face.u
            glyph: ""
            rotation: Lock.menuOpen ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: Lock.settle } }
            onClicked: Lock.menuOpen = !Lock.menuOpen
        }
    }

    Item {
        id: menu
        property real p: Lock.menuOpen && face.main && !Lock.leaving ? 1 : 0
        Behavior on p { NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: Lock.settle } }

        x: face.margin
        y: gearReveal.y - height - 10 * face.u
        width: 250 * face.u
        height: menuCol.implicitHeight + 24 * face.u
        opacity: p
        visible: p > 0.001
        scale: 0.94 + 0.06 * p
        transformOrigin: Item.BottomLeft
        transform: Translate { y: (1 - menu.p) * 10 * face.u }

        Card { anchors.fill: parent }
        // Swallows clicks so they don't reach the background (which closes the menu).
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Column {
            id: menuCol
            x: 12 * face.u
            y: 12 * face.u
            width: parent.width - 24 * face.u
            spacing: 2 * face.u

            Text {
                leftPadding: 8 * face.u
                bottomPadding: 6 * face.u
                text: "Lock screen"
                font.family: Lock.sans
                font.pixelSize: 13 * face.u
                color: "#80ffffff"
            }
            Repeater {
                model: Lock.labels
                Toggle {
                    required property var modelData
                    u: face.u
                    label: modelData[1]
                    checked: !!Lock.cfg[modelData[0]]
                    onToggled: Lock.set(modelData[0], !checked)
                }
            }
        }
    }

    // Preview only: there is no lock to leave, so say how to.
    Text {
        visible: Lock.preview
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12 * face.u
        text: "Preview · Esc closes"
        font.family: Lock.sans
        font.pixelSize: 12 * face.u
        color: "#80ffffff"
    }
}
