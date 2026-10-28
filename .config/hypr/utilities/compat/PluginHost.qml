pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Hex: host mínimo para plugins de barra do Omarchy dentro do elifouts.
//
// Lê compat/plugins.json, carrega o Service.qml de cada plugin uma única vez
// (o processo de utilitários é um só para todos os monitores) e guarda os
// widgets vivos de cada plugin para bar.moduleWidgets() e para o controle de
// qual painel está aberto.
Singleton {
    id: root

    readonly property string dir: Quickshell.shellDir
    property var entries: []
    property var services: ({})
    property var widgets: ({})
    property var activePopout: null

    // O que os plugins recebem como `shell`. Eles só usam serviceFor().
    readonly property QtObject shellApi: QtObject {
        function serviceFor(id) { return root.services[String(id || "")] || null }
    }

    function url(entry, file) {
        return "file://" + root.dir + "/" + entry.dir + "/" + file
    }

    function manifestFor(entry) {
        return { id: entry.id, settings: entry.settings || {} }
    }

    function load(text) {
        var list = []
        try { list = JSON.parse(text) } catch (e) { console.warn("compat: plugins.json inválido:", e); return }
        root.entries = list.filter(e => e && e.id && e.dir && e.barWidget)
        for (var i = 0; i < root.entries.length; i++) startService(root.entries[i])
    }

    function startService(entry) {
        if (!entry.service || root.services[entry.id]) return
        var comp = Qt.createComponent(url(entry, entry.service), Component.PreferSynchronous)
        var finish = function() {
            if (comp.status !== Component.Ready) {
                console.warn("compat: serviço de " + entry.id + " falhou:", comp.errorString())
                return
            }
            var inst = comp.createObject(null)
            if (!inst) { console.warn("compat: serviço de " + entry.id + " não criou"); return }
            if ("shell" in inst) inst.shell = root.shellApi
            if ("manifest" in inst) inst.manifest = root.manifestFor(entry)
            var next = Object.assign({}, root.services)
            next[entry.id] = inst
            root.services = next
        }
        if (comp.status === Component.Loading) comp.statusChanged.connect(finish)
        else finish()
    }

    function register(id, item) {
        var next = Object.assign({}, root.widgets)
        next[id] = (next[id] || []).filter(w => w !== item).concat([item])
        root.widgets = next
    }

    function unregister(id, item) {
        var next = Object.assign({}, root.widgets)
        next[id] = (next[id] || []).filter(w => w !== item)
        root.widgets = next
        if (root.activePopout && root.activePopout === item) root.activePopout = null
    }

    function moduleWidgets(id) { return (root.widgets[id] || []).slice() }

    // Só um painel aberto por vez: abrir um fecha o anterior.
    function requestPopout(owner) {
        var prev = root.activePopout
        if (prev && prev !== owner) {
            try { if (typeof prev.close === "function") prev.close() } catch (e) {}
        }
        root.activePopout = owner
    }

    function releasePopout(owner) {
        if (root.activePopout === owner) root.activePopout = null
    }

    function run(command) {
        if (command) Quickshell.execDetached(["sh", "-c", command])
    }

    FileView {
        path: root.dir + "/compat/plugins.json"
        watchChanges: false
        printErrors: true
        onLoaded: root.load(text())
    }
}
