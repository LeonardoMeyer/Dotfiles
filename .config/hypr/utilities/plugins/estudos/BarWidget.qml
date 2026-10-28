import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Hex: plugin "Estudos" — GitHub (contribuições e commits recentes).
BarWidget {
    id: root
    moduleName: "hex.estudos"

    readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("bin/hex-estudos")).replace(/^(file|qs):\/\//, ""))
    readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
    readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.55)
    readonly property color accent: Commons.Color.accent
    readonly property string ff: bar ? bar.fontFamily : Style.font.family

    property bool opened: false
    property var gh: ({})
    property bool loading: false

    function open() { opened = true; if (!gh.login || stale()) reload() }
    function close() { opened = false }
    function toggle() { opened ? close() : open() }
    function reload() { if (!loading) { loading = true; ghProc.running = true } }
    property double fetchedAt: 0
    function stale() { return Date.now() - fetchedAt > 15 * 60 * 1000 }

    function ago(iso) {
        var s = (Date.now() - new Date(iso).getTime()) / 1000
        if (s < 3600) return Math.max(1, Math.round(s / 60)) + " min"
        if (s < 86400) return Math.round(s / 3600) + " h"
        return Math.round(s / 86400) + " d"
    }
    function openUrl(u) { Quickshell.execDetached(["xdg-open", u]); close() }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰑴"
        // número de commits de hoje ao lado do ícone
        labelText: root.gh.today > 0 ? String(root.gh.today) : ""
        tooltipText: "Estudos"
        active: root.opened
        onPressed: function(b) { root.toggle() }
    }

    Timer { interval: 15 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.reload() }

    Process {
        id: ghProc
        command: [root.helper, "github"]
        onExited: { root.loading = false; ghFile.reload() }
    }
    FileView {
        id: ghFile
        path: Quickshell.env("HOME") + "/.cache/hex-estudos/github.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.gh = JSON.parse(text()); root.fetchedAt = Date.now() } catch (e) {} }
    }

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
    component Stat: ColumnLayout {
        id: stat
        property string big
        property string small
        spacing: 0
        Text { text: stat.big; color: root.fg; font.family: root.ff; font.pixelSize: Style.font.heading; font.bold: true }
        Text { text: stat.small; color: root.dim; font.family: root.ff; font.pixelSize: Style.font.caption }
    }

    PopupCard {
        id: card
        anchorItem: button
        bar: root.bar
        owner: root
        open: root.opened
        contentWidth: card.fittedContentWidth(Style.space(400))
        contentHeight: card.fittedContentHeight(col.implicitHeight)

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Style.space(12)

            RowLayout {
                Layout.fillWidth: true
                Text { text: "󰑴"; color: root.accent; font.family: root.ff; font.pixelSize: Style.font.heading }
                Text { text: "Estudos"; color: root.fg; font.family: root.ff; font.pixelSize: Style.font.title; font.bold: true }
                Item { Layout.fillWidth: true }
                Value { text: root.loading ? "atualizando…" : ""; color: root.dim; font.pixelSize: Style.font.caption }
            }

            // ------------------------------------------------ GitHub
            RowLayout {
                Layout.fillWidth: true
                Caption { text: "GitHub" + (root.gh.login ? " · " + root.gh.login : "") }
                Item { Layout.fillWidth: true }
                Button {
                    text: "Abrir"
                    bordered: true
                    enabled: !!root.gh.login
                    onClicked: root.openUrl("https://github.com/" + root.gh.login)
                }
            }
            Value {
                visible: !!root.gh.error
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: root.gh.error || ""
                color: Commons.Color.urgent
            }

            RowLayout {
                visible: !!root.gh.login
                Layout.fillWidth: true
                spacing: Style.space(18)
                Stat { big: String(root.gh.today ?? 0); small: "hoje" }
                Stat { big: String(root.gh.week ?? 0); small: "7 dias" }
                Stat { big: String(root.gh.streak ?? 0); small: "dias seguidos" }
                Stat { big: String(root.gh.total ?? 0); small: "no ano" }
            }

            // mapa de contribuições: 17 semanas, uma coluna por semana
            Grid {
                visible: !!root.gh.calendar
                Layout.alignment: Qt.AlignHCenter
                rows: 7
                flow: Grid.TopToBottom
                spacing: Style.space(3)
                Repeater {
                    model: root.gh.calendar || []
                    delegate: Rectangle {
                        required property var modelData
                        width: Style.space(14)
                        height: width
                        radius: Style.space(3)
                        color: modelData.level === 0
                            ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                            : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25 + 0.1875 * modelData.level)
                    }
                }
            }

            Caption { visible: (root.gh.commits || []).length > 0; text: "Commits recentes" }
            Repeater {
                model: root.gh.commits || []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: row.implicitHeight + Style.space(8)
                    radius: Style.space(6)
                    color: hover.hovered ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08) : "transparent"
                    HoverHandler { id: hover }
                    RowLayout {
                        id: row
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Style.space(6)
                        anchors.rightMargin: Style.space(6)
                        spacing: Style.space(8)
                        Value { text: modelData.repo; color: root.accent; Layout.maximumWidth: Style.space(110); elide: Text.ElideRight }
                        Value { text: modelData.message; Layout.fillWidth: true; elide: Text.ElideRight }
                        Value { text: root.ago(modelData.date); color: root.dim; font.pixelSize: Style.font.caption }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openUrl(modelData.url)
                    }
                }
            }

        }
    }
}
