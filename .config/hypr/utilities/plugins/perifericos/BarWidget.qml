import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Hex: plugin "Periféricos" — teclado Logitech PRO (cor pelo OpenRGB) e
// mouse G403 HERO (DPI, taxa, botões e luz pelo libratbag, gravado no mouse).
BarWidget {
    id: root
    moduleName: "hex.perifericos"

    readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("bin/hex-perifericos")).replace(/^(file|qs):\/\//, ""))
    readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property color accent: Commons.Color.accent
    readonly property string ff: bar ? bar.fontFamily : Style.font.family

    readonly property var palette: ["ff2d2d", "ff7a00", "ffd500", "00e676", "00e5ff", "2f6bff", "8a2be2", "ff00c8", "ffffff"]
    readonly property var buttonNames: ({ 2: "Clique da roda", 3: "Lateral de trás", 4: "Lateral da frente", 5: "Botão de DPI" })
    readonly property var actions: [
        { value: "padrao", label: "Padrão" }, { value: "voltar", label: "Voltar" }, { value: "avancar", label: "Avançar" },
        { value: "copiar", label: "Copiar" }, { value: "colar", label: "Colar" }, { value: "desfazer", label: "Desfazer" },
        { value: "meio", label: "Clique do meio" }, { value: "dpi", label: "Trocar DPI" }, { value: "desativado", label: "Desativado" }
    ]

    property bool opened: false
    property var info: ({})
    property var queue: []
    property bool busy: false
    property string errorText: ""
    property int pickedButton: -1

    readonly property var mouse: info.mouse || null
    readonly property var kb: info.kb || { mode: "static", color: "ffffff" }
    readonly property var follow: info.follow || { kb: false, mouse: false }

    function open() { opened = true; refresh() }
    function close() { opened = false }
    function toggle() { opened ? close() : open() }
    function refresh() { if (!statusProc.running) statusProc.running = true }

    function actionLabel(v) {
        for (var i = 0; i < actions.length; i++) if (actions[i].value === v) return actions[i].label
        return "Personalizado"
    }

    // fila: um comando por vez (cada escrita no aparelho leva 1 a 3 s)
    function exec(args) {
        queue = queue.concat([args])
        pump()
    }
    function pump() {
        if (busy || queue.length === 0) return
        busy = true
        errorText = ""
        writeProc.command = [helper].concat(queue[0])
        queue = queue.slice(1)
        writeProc.running = true
    }

    function kbColor(c) {
        var mode = (kb.mode === "breathing") ? "breathing" : "static"
        exec(["kb", mode, c])
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰍽"
        tooltipText: "Periféricos"
        active: root.opened
        onPressed: function(b) { root.toggle() }
    }

    Process {
        id: statusProc
        command: [root.helper, "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.info = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: writeProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { var r = JSON.parse(text); if (r.error) root.errorText = r.error } catch (e) {}
            }
        }
        onExited: { root.busy = false; root.refresh(); root.pump() }
    }

    // ---------------------------------------------------------- peças
    component Caption: Text {
        color: root.dim
        font.family: root.ff
        font.pixelSize: Style.font.caption
        font.letterSpacing: 1
        font.capitalization: Font.AllUppercase
    }
    component Value: Text {
        color: root.fg
        font.family: root.ff
        font.pixelSize: Style.font.body
    }
    component Swatch: Rectangle {
        id: sw
        property string hex: "ffffff"
        property bool selected: false
        signal picked()
        width: Style.space(22)
        height: width
        radius: width / 2
        color: "#" + hex
        border.width: selected ? 2 : 1
        border.color: selected ? root.fg : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.25)
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: !root.busy
            onClicked: sw.picked()
        }
    }
    component Sep: Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
    }

    // ---------------------------------------------------------- painel
    PopupCard {
        id: card
        anchorItem: button
        bar: root.bar
        owner: root
        open: root.opened
        contentWidth: card.fittedContentWidth(Style.space(400))
        contentHeight: card.fittedContentHeight(col.implicitHeight)

        Flickable {
            anchors.fill: parent
            contentWidth: width
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            ColumnLayout {
                id: col
                width: parent.width
                spacing: Style.space(12)

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "󰍽"; color: root.accent; font.family: root.ff; font.pixelSize: Style.font.heading }
                    Text { text: "Periféricos"; color: root.fg; font.family: root.ff; font.pixelSize: Style.font.title; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Value {
                        text: root.busy ? "aplicando…" : ""
                        color: root.dim
                        font.pixelSize: Style.font.caption
                    }
                }
                Value {
                    visible: root.errorText !== ""
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: "Erro: " + root.errorText
                    color: Commons.Color.urgent
                }

                // ------------------------------------------------ teclado
                Caption { text: "Teclado · Logitech PRO" }
                ButtonGroup {
                    options: [
                        { value: "static", label: "Fixo" }, { value: "breathing", label: "Respirando" },
                        { value: "cycle", label: "Arco-íris" }, { value: "off", label: "Desligado" }
                    ]
                    value: root.kb.mode
                    onChanged: function(v) { root.exec(["kb", v, root.kb.color || "ffffff"]) }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Style.space(8)
                    Swatch {
                        visible: !!root.info.theme
                        hex: root.info.theme || "ffffff"
                        selected: root.follow.kb
                        onPicked: root.exec(["follow", "kb", root.follow.kb ? "off" : "on"])
                        Text { anchors.centerIn: parent; text: "󰸌"; font.family: root.ff; font.pixelSize: Style.font.caption; color: "#000000" }
                    }
                    Repeater {
                        model: root.palette
                        delegate: Swatch {
                            required property string modelData
                            hex: modelData
                            selected: !root.follow.kb && (root.kb.color || "") === modelData
                            onPicked: {
                                if (root.follow.kb) root.exec(["follow", "kb", "off"])
                                root.kbColor(modelData)
                            }
                        }
                    }
                }
                Value {
                    text: root.follow.kb ? "Seguindo a cor do wallpaper (clique no 󰸌 para parar)" : "Clique no 󰸌 para o teclado seguir o wallpaper"
                    color: root.dim
                    font.pixelSize: Style.font.caption
                    visible: !!root.info.theme
                }

                Sep {}

                // ------------------------------------------------ mouse
                Caption { text: "Mouse · G403 HERO" }
                Value {
                    visible: !root.mouse
                    text: "Mouse não encontrado pelo libratbag (o ratbagd está rodando?)"
                    color: root.dim
                }

                ColumnLayout {
                    visible: !!root.mouse
                    Layout.fillWidth: true
                    spacing: Style.space(10)

                    Value { text: "DPI (clique para usar, − e + ajustam o nível ativo)"; color: root.dim; font.pixelSize: Style.font.caption }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        Repeater {
                            model: root.mouse ? root.mouse.resolutions.filter(r => !r.disabled) : []
                            delegate: Button {
                                required property var modelData
                                text: String(modelData.dpi)
                                bordered: true
                                selected: modelData.active
                                onClicked: if (!modelData.active) root.exec(["dpi-active", String(modelData.slot)])
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "−"
                            bordered: true
                            onClicked: {
                                var a = root.mouse.resolutions.find(r => r.active)
                                if (a && a.dpi > 100) root.exec(["dpi", String(a.slot), String(Math.max(100, a.dpi - 50))])
                            }
                        }
                        Button {
                            text: "+"
                            bordered: true
                            onClicked: {
                                var a = root.mouse.resolutions.find(r => r.active)
                                if (a && a.dpi < 25600) root.exec(["dpi", String(a.slot), String(Math.min(25600, a.dpi + 50))])
                            }
                        }
                    }

                    Value { text: "Taxa de atualização"; color: root.dim; font.pixelSize: Style.font.caption }
                    ButtonGroup {
                        options: [
                            { value: "125", label: "125 Hz" }, { value: "250", label: "250 Hz" },
                            { value: "500", label: "500 Hz" }, { value: "1000", label: "1000 Hz" }
                        ]
                        value: root.mouse ? String(root.mouse.rate) : ""
                        onChanged: function(v) { root.exec(["rate", v]) }
                    }

                    Value { text: "Botões (clique num botão para trocar a função)"; color: root.dim; font.pixelSize: Style.font.caption }
                    Repeater {
                        model: root.mouse ? root.mouse.buttons.filter(b => b.editable) : []
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: Style.space(30)
                            radius: Style.space(6)
                            color: root.pickedButton === modelData.n ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1) : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Style.space(8)
                                anchors.rightMargin: Style.space(8)
                                Value { text: root.buttonNames[modelData.n] || ("Botão " + modelData.n) }
                                Item { Layout.fillWidth: true }
                                Value { text: root.actionLabel(modelData.action); color: root.accent }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pickedButton = (root.pickedButton === modelData.n ? -1 : modelData.n)
                            }
                        }
                    }
                    Flow {
                        visible: root.pickedButton >= 0
                        Layout.fillWidth: true
                        spacing: Style.space(6)
                        Repeater {
                            model: root.actions
                            delegate: Button {
                                required property var modelData
                                text: modelData.label
                                bordered: true
                                onClicked: {
                                    root.exec(["button", String(root.pickedButton), modelData.value])
                                    root.pickedButton = -1
                                }
                            }
                        }
                    }

                    Value { text: "Luz do mouse"; color: root.dim; font.pixelSize: Style.font.caption }
                    Repeater {
                        model: root.mouse ? root.mouse.leds : []
                        delegate: RowLayout {
                            id: ledRow
                            required property var modelData
                            // índice do LED para os filhos (o Repeater interno também usa modelData)
                            readonly property int n: modelData.n
                            Layout.fillWidth: true
                            spacing: Style.space(6)
                            Value { text: "Zona " + (modelData.n + 1); Layout.preferredWidth: Style.space(56) }
                            Repeater {
                                model: root.palette
                                delegate: Swatch {
                                    required property string modelData
                                    width: Style.space(18)
                                    hex: modelData
                                    onPicked: root.exec(["led", String(ledRow.n), "on", modelData])
                                }
                            }
                            Button {
                                text: "Off"
                                bordered: true
                                onClicked: root.exec(["led", String(ledRow.n), "off"])
                            }
                        }
                    }
                    Button {
                        text: root.follow.mouse ? "Luz do mouse segue o wallpaper: sim" : "Luz do mouse segue o wallpaper: não"
                        bordered: true
                        selected: root.follow.mouse
                        onClicked: root.exec(["follow", "mouse", root.follow.mouse ? "off" : "on"])
                    }
                }
            }
        }
    }
}
