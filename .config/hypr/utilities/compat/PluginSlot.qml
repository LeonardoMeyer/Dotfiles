import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Hex: um espaço na barra do elifouts que carrega o widget de um plugin do
// Omarchy e entrega a ele um objeto `bar` compatível (PluginBarApi).
Item {
    id: slot

    property var entry: ({})
    // altura da pílula do elifouts; os widgets se ajustam a ela
    property int barSize: 30
    // espaço do topo da tela até o fim da barra, usado para posicionar os painéis
    property int barReach: barSize + 12

    implicitWidth: loader.item ? Math.max(loader.item.implicitWidth, loader.item.width) : 0
    implicitHeight: barSize
    visible: loader.status === Loader.Ready

    PluginBarApi {
        id: api
        pluginId: slot.entry.id || ""
        moduleName: slot.entry.id || ""
        shell: PluginHost.shellApi
        foreground: Commons.Color.foreground
        barForeground: Commons.Color.foreground
        background: Commons.Color.background
        urgent: Commons.Color.urgent
        fontFamily: Style.font.family
        position: "top"
        vertical: false
        barSize: slot.barSize
        transparent: true
        activePopout: PluginHost.activePopout
        layoutConfig: ({})

        Component.onCompleted: {
            api._requestPopout = owner => PluginHost.requestPopout(owner)
            api._releasePopout = owner => PluginHost.releasePopout(owner)
            api._moduleWidgets = id => PluginHost.moduleWidgets(id)
            api._run = cmd => PluginHost.run(cmd)
            api._targetBelongsToWindow = (target, win) => !!(target && target.QsWindow && target.QsWindow.window === win)
        }
        // os painéis medem a barra por monitor; a do elifouts é igual em todos
        function barSizeFor(screenName) { return slot.barReach }
    }

    Loader {
        id: loader
        anchors.verticalCenter: parent.verticalCenter
        active: !!slot.entry.id
        source: slot.entry.id ? PluginHost.url(slot.entry, slot.entry.barWidget) : ""
        onLoaded: {
            var it = item
            if ("bar" in it) it.bar = api
            if ("settings" in it) it.settings = PluginHost.settingsFor(slot.entry)
            if ("shell" in it) it.shell = PluginHost.shellApi
            if ("manifest" in it) it.manifest = PluginHost.manifestFor(slot.entry)
            if ("service" in it) it.service = PluginHost.services[slot.entry.id] || null
            if (!it.height) it.height = slot.barSize
            PluginHost.register(slot.entry.id, it)
        }
        onStatusChanged: {
            if (status === Loader.Error)
                console.warn("compat: widget de " + slot.entry.id + " falhou ao carregar")
        }
    }

    // o serviço pode terminar de carregar depois do widget
    Connections {
        target: PluginHost
        function onServicesChanged() {
            var it = loader.item
            if (it && "service" in it && !it.service) it.service = PluginHost.services[slot.entry.id] || null
        }
    }

    Component.onDestruction: if (loader.item) PluginHost.unregister(slot.entry.id, loader.item)
}
