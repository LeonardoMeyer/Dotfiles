import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Hex: plugin "Diário" — um jornal de ontem feito com o que aconteceu no PC
// (commits, Claude Code, foco, sistema e clima) e notícias de Bitcoin,
// tecnologia, cyber e eventos de tecnologia em São Paulo. A edição sai uma vez por dia,
// na primeira hora em que a sessão estiver aberta depois das 5h; o ponto no
// ícone avisa que tem edição nova sem ler.
BarWidget {
    id: root
    moduleName: "hex.diario"

    readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("bin/hex-diario")).replace(/^(file|qs):\/\//, ""))
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/hex-diario"
    readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property color accent: Commons.Color.accent
    readonly property string ff: bar ? bar.fontFamily : Style.font.family

    property bool opened: false
    property var latest: ({})
    property string readDate: ""
    property bool building: false

    readonly property bool unread: !!latest.date && latest.date !== readDate

    function open() { opened = true }
    function close() { opened = false }
    function toggle() { opened ? close() : open() }

    function yesterday() {
        var d = new Date(); d.setDate(d.getDate() - 1)
        return Qt.formatDate(d, "yyyy-MM-dd")
    }
    function build() { if (!building) { building = true; buildProc.running = true } }
    function read() {
        if (!latest.path) return
        Quickshell.execDetached(["xdg-open", latest.path])
        readFile.setText(latest.date)
        readDate = latest.date
        close()
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰎕"
        tooltipText: root.unread ? "Diário: edição nova" : "Diário"
        active: root.opened
        onPressed: function(b) {
            if (b === Qt.RightButton) root.read()
            else root.toggle()
        }
    }

    // pontinho de "não lido"
    Rectangle {
        visible: root.unread
        width: Style.space(6)
        height: width
        radius: width / 2
        color: root.accent
        x: button.x + button.width / 2 + Style.space(5)
        y: button.y + button.height / 2 - Style.space(9)
    }

    // a cada 20 min: se já passou das 5h e a edição de ontem não existe, monta
    Timer {
        interval: 20 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var isLeader = !root.bar || typeof root.bar.moduleWidgets !== "function"
                || root.bar.moduleWidgets(root.moduleName)[0] === root
            if (isLeader && new Date().getHours() >= 5 && root.latest.date !== root.yesterday()) root.build()
        }
    }

    Process {
        id: buildProc
        command: [root.helper, "build"]
        onExited: { root.building = false; latestFile.reload() }
    }
    FileView {
        id: latestFile
        path: root.cacheDir + "/latest.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.latest = JSON.parse(text()) } catch (e) {} }
    }
    FileView {
        id: readFile
        path: root.cacheDir + "/read"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.readDate = text().trim()
    }

    component Value: Text {
        color: root.fg
        font.family: root.ff
        font.pixelSize: Style.font.body
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
            spacing: Style.space(10)

            RowLayout {
                Layout.fillWidth: true
                Text { text: "󰎕"; color: root.accent; font.family: root.ff; font.pixelSize: Style.font.heading }
                Text { text: "Diário"; color: root.fg; font.family: root.ff; font.pixelSize: Style.font.title; font.bold: true }
                Item { Layout.fillWidth: true }
                Value {
                    text: root.building ? "montando…" : (root.latest.edition ? "nº " + root.latest.edition : "")
                    color: root.dim
                    font.pixelSize: Style.font.caption
                }
            }

            Value {
                visible: !root.latest.date
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: root.dim
                text: root.building ? "Montando a primeira edição…" : "Nenhuma edição ainda. Clique em Montar agora."
            }

            Repeater {
                model: root.latest.stories || []
                delegate: ColumnLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: Style.space(2)
                    Text {
                        text: modelData.kicker
                        color: root.accent
                        font.family: root.ff
                        font.pixelSize: Style.font.caption
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        color: root.fg
                        wrapMode: Text.Wrap
                        font.family: "serif"
                        font.pixelSize: index === 0 ? Style.font.heading + 4 : Style.font.title
                        font.bold: true
                    }
                }
            }

            // cotação do bitcoin e próximo evento de tecnologia em SP
            Value {
                visible: !!root.latest.btc
                Layout.fillWidth: true
                text: root.latest.btc
                    ? "₿  R$ " + Math.round(root.latest.btc.brl).toLocaleString(Qt.locale("pt_BR"), "f", 0)
                      + "   " + (root.latest.btc.change >= 0 ? "▲ " : "▼ ") + Math.abs(root.latest.btc.change).toFixed(2).replace(".", ",") + "%"
                    : ""
                color: root.latest.btc && root.latest.btc.change < 0 ? Commons.Color.urgent : root.fg
            }
            Repeater {
                model: (root.latest.events || []).slice(0, 2)
                delegate: Value {
                    required property var modelData
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: "󰃭  " + modelData.when + " · " + modelData.title
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Quickshell.execDetached(["xdg-open", modelData.url]); root.close() }
                    }
                }
            }

            Value {
                visible: !!root.latest.today
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: root.dim
                text: root.latest.today
                    ? "Hoje em " + root.latest.city + ": " + root.latest.today.icon + " " + root.latest.today.desc
                      + ", " + root.latest.today.max + "° / " + root.latest.today.min + "°"
                    : ""
            }

            RowLayout {
                Layout.fillWidth: true
                Button { text: "Montar agora"; bordered: true; enabled: !root.building; onClicked: root.build() }
                Item { Layout.fillWidth: true }
                Button { text: "Ler edição"; bordered: true; enabled: !!root.latest.path; onClicked: root.read() }
            }
        }
    }
}
