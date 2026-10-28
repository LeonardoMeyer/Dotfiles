import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Hex: plugin "Sistema" no estilo dos plugins do Omarchy.
// Ícone na barra (com o número de atualizações) e um painel com monitor,
// atualizações e limpeza. Atualizar e limpar abrem um terminal, onde cada
// passo pede confirmação; o painel em si só lê.
BarWidget {
    id: root
    moduleName: "hex.sistema"

    readonly property string bin: decodeURIComponent(String(Qt.resolvedUrl("bin")).replace(/^(file|qs):\/\//, ""))
    readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property color accent: Commons.Color.accent
    readonly property color hot: Commons.Color.urgent
    readonly property string ff: bar ? bar.fontFamily : Style.font.family

    property bool opened: false
    property var st: ({})
    property var sc: ({ updates: {}, clean: {} })
    property bool scanning: false

    readonly property int updates: (sc.updates.repo || 0) + (sc.updates.aur || 0) + (sc.updates.flatpak || 0)

    function open() { opened = true; statsProc.running = true; if (!sc.time || Date.now() / 1000 - sc.time > 600) rescan() }
    function close() { opened = false }
    function toggle() { opened ? close() : open() }
    function rescan() { if (!scanning) { scanning = true; scanProc.running = true } }

    function human(b) {
        if (b === undefined || b === null) return "—"
        var u = ["B", "KB", "MB", "GB", "TB"], i = 0
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++ }
        return (i === 0 ? b : b.toFixed(b < 10 ? 1 : 0)) + " " + u[i]
    }
    function terminal(cmd) {
        Quickshell.execDetached(["kitty", "--class", "floating-term", "-e", "bash", "-c",
            cmd + "; echo; read -rp 'Enter para fechar'"])
        close()
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰍛"
        labelText: root.updates > 0 ? String(root.updates) : ""
        tooltipText: root.updates > 0 ? root.updates + " atualizações" : "Sistema"
        active: root.opened
        onPressed: function(b) {
            if (b === Qt.RightButton) root.terminal("yay -Syu; command -v flatpak >/dev/null && flatpak update")
            else root.toggle()
        }
    }

    // atualizações: na abertura da sessão e a cada 30 min
    Timer { interval: 30 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.rescan() }
    // monitor: só enquanto o painel está aberto
    Timer { interval: 2000; running: root.opened; repeat: true; onTriggered: statsProc.running = true }

    Process {
        id: statsProc
        command: [root.bin + "/hex-sistema", "stats"]
        stdout: StdioCollector { onStreamFinished: { try { root.st = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: scanProc
        command: [root.bin + "/hex-sistema", "scan"]
        onExited: root.scanning = false
    }
    // o resultado do scan fica num arquivo; todos os monitores leem o mesmo
    FileView {
        path: Quickshell.env("HOME") + "/.cache/hex-sistema/scan.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.sc = JSON.parse(text()) } catch (e) {} }
    }

    // ---------------------------------------------------------- painel
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
    component Meter: ColumnLayout {
        id: meter
        property string label
        property string value
        property real frac: 0
        Layout.fillWidth: true
        spacing: Style.space(4)
        RowLayout {
            Layout.fillWidth: true
            Value { text: meter.label; color: root.dim }
            Item { Layout.fillWidth: true }
            Value { text: meter.value }
        }
        Rectangle {
            Layout.fillWidth: true
            height: Style.space(4)
            radius: height / 2
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, meter.frac))
                height: parent.height
                radius: parent.radius
                color: meter.frac > 0.85 ? root.hot : root.accent
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }
    }
    component Row2: RowLayout {
        id: row2
        property string label
        property string value
        Layout.fillWidth: true
        Value { text: row2.label; color: root.dim }
        Item { Layout.fillWidth: true }
        Value { text: row2.value }
    }
    component Sep: Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
    }

    PopupCard {
        id: card
        anchorItem: button
        bar: root.bar
        owner: root
        open: root.opened
        contentWidth: card.fittedContentWidth(Style.space(360))
        contentHeight: card.fittedContentHeight(col.implicitHeight)

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Style.space(12)

            RowLayout {
                Layout.fillWidth: true
                Text { text: "󰍛"; color: root.accent; font.family: root.ff; font.pixelSize: Style.font.heading }
                Text { text: "Sistema"; color: root.fg; font.family: root.ff; font.pixelSize: Style.font.title; font.bold: true }
                Item { Layout.fillWidth: true }
                Button { text: "btop"; bordered: true; onClicked: { Quickshell.execDetached(["kitty", "-e", "btop"]); root.close() } }
            }

            Caption { text: "Monitor" }
            Meter {
                label: "CPU" + (root.st.cpuTemp ? "  " + root.st.cpuTemp + "°C" : "")
                value: (root.st.cpu ?? 0) + "%"
                frac: (root.st.cpu ?? 0) / 100
            }
            Meter {
                visible: root.st.gpu !== undefined && root.st.gpu !== null
                label: "GPU" + (root.st.gpuTemp ? "  " + root.st.gpuTemp + "°C" : "")
                value: (root.st.gpu ?? 0) + "%"
                frac: (root.st.gpu ?? 0) / 100
            }
            Meter {
                label: "RAM"
                value: root.human(root.st.memUsed) + " / " + root.human(root.st.memTotal)
                frac: root.st.memTotal ? root.st.memUsed / root.st.memTotal : 0
            }
            Meter {
                label: "Disco (home)"
                value: root.human(root.st.diskUsed) + " / " + root.human(root.st.diskTotal)
                frac: root.st.diskTotal ? root.st.diskUsed / root.st.diskTotal : 0
            }

            Sep {}
            RowLayout {
                Layout.fillWidth: true
                Caption { text: "Atualizações" }
                Item { Layout.fillWidth: true }
                Value { text: root.scanning ? "verificando…" : ""; color: root.dim; font.pixelSize: Style.font.caption }
            }
            Row2 { label: "Pacotes do Arch"; value: root.sc.updates.repo ?? "—" }
            Row2 { label: "AUR"; value: root.sc.updates.aur ?? "—" }
            Row2 { label: "Flatpak"; value: root.sc.updates.flatpak ?? "—" }
            RowLayout {
                Layout.fillWidth: true
                Button { text: "Verificar"; bordered: true; onClicked: root.rescan() }
                Item { Layout.fillWidth: true }
                Button {
                    text: "Atualizar tudo"
                    bordered: true
                    onClicked: root.terminal("yay -Syu; command -v flatpak >/dev/null && flatpak update")
                }
            }

            Sep {}
            Caption { text: "Limpeza" }
            Row2 { label: "Cache do pacman"; value: root.human(root.sc.clean.pacman) }
            Row2 { label: "Compilações do AUR"; value: root.human(root.sc.clean.yay) }
            Row2 { label: "Cache dos apps (~/.cache)"; value: root.human(root.sc.clean.userCache) }
            Row2 { label: "Logs do sistema"; value: root.human(root.sc.clean.journal) }
            Row2 { label: "Lixeira"; value: root.human(root.sc.clean.trash) }
            Row2 { label: "Pacotes órfãos"; value: root.sc.clean.orphans ?? "—" }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    text: "Limpar (passo a passo)"
                    bordered: true
                    onClicked: root.terminal(root.bin + "/hex-sistema-limpar; " + root.bin + "/hex-sistema scan >/dev/null")
                }
            }
        }
    }
}
