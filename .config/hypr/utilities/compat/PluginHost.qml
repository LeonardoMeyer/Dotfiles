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
    property var panels: ({})
    // ajustes que cada plugin salva (pin da contagem, rótulo do Konobeat...)
    property var overrides: ({})
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/hex-plugins/settings.json"

    // O que os plugins recebem como `shell`: o subconjunto da API do Omarchy
    // que os plugins instalados usam de verdade.
    readonly property QtObject shellApi: QtObject {
        // config no formato do shell.json do Omarchy, montada a partir da nossa lista
        readonly property var shellConfig: ({ bar: { layout: { right: root.entries.map(e => Object.assign({ id: e.id }, root.settingsFor(e))) } } })
        function serviceFor(id) { return root.services[String(id || "")] || null }
        function updateEntryInline(id, entry) { root.saveSettings(String(id || ""), entry || {}) }
        function toggle(id, payload) { return root.togglePanel(String(id || ""), payload || "{}") }
        function show(id, payload) { return root.showPanel(String(id || ""), payload || "{}") }
        function hide(id) { return root.hidePanel(String(id || "")) }
        // OSD do Omarchy: o elifouts tem o dele, aqui é ignorado
        function summon(target, payload) { return false }
    }

    function settingsFor(entry) {
        var base = Object.assign({}, entry.settings || {})
        var extra = root.overrides[entry.id] || {}
        for (var k in extra) if (k !== "id") base[k] = extra[k]
        return base
    }

    function saveSettings(id, entry) {
        var next = Object.assign({}, root.overrides)
        next[id] = Object.assign({}, entry)
        delete next[id].id
        root.overrides = next
        stateView.setText(JSON.stringify(next, null, 2))
        // os widgets abertos recebem os ajustes novos
        var list = root.widgets[id] || []
        var e = root.entries.find(x => x.id === id)
        for (var i = 0; i < list.length; i++) if (list[i] && e && "settings" in list[i]) list[i].settings = root.settingsFor(e)
    }

    // painéis (plugins do tipo "panel", como o xadrez): criados na primeira vez
    function panelFor(id) {
        if (root.panels[id]) return root.panels[id]
        var entry = root.entries.find(x => x.id === id)
        if (!entry || !entry.panel) return null
        var comp = Qt.createComponent(url(entry, entry.panel), Component.PreferSynchronous)
        if (comp.status !== Component.Ready) { console.warn("compat: painel de " + id + " falhou:", comp.errorString()); return null }
        var inst = comp.createObject(root)
        if (!inst) return null
        if ("shell" in inst) inst.shell = root.shellApi
        if ("manifest" in inst) inst.manifest = root.manifestFor(entry)
        if ("service" in inst) inst.service = root.services[id] || null
        var next = Object.assign({}, root.panels)
        next[id] = inst
        root.panels = next
        return inst
    }
    function isOpen(p) { return p && p.opened === true }
    function showPanel(id, payload) {
        var p = panelFor(id)
        if (!p) return false
        if (typeof p.open === "function") p.open(payload)
        else p.opened = true
        return true
    }
    function hidePanel(id) {
        var p = root.panels[id]
        if (!p) return false
        if (typeof p.close === "function") p.close()
        else p.opened = false
        return true
    }
    function togglePanel(id, payload) {
        return isOpen(root.panels[id]) ? hidePanel(id) : showPanel(id, payload)
    }

    function url(entry, file) {
        return "file://" + root.dir + "/" + entry.dir + "/" + file
    }

    function manifestFor(entry) {
        return { id: entry.id, settings: root.settingsFor(entry) }
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
        id: stateView
        path: root.stateFile
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try { root.overrides = JSON.parse(text()) || {} } catch (e) { return }
            for (var i = 0; i < root.entries.length; i++) {
                var e = root.entries[i], list = root.widgets[e.id] || []
                for (var j = 0; j < list.length; j++) if (list[j] && "settings" in list[j]) list[j].settings = root.settingsFor(e)
            }
        }
        onLoadFailed: Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/hex-plugins"])
    }

    // os plugins também podem ser chamados de fora: omarchy-shell <id> <função>
    IpcHandler {
        target: "hex.plugins"
        function toggle(id: string): string { return root.togglePanel(id, "{}") ? "ok" : "sem painel" }
        function list(): string { return root.entries.map(e => e.id).join("\n") }
    }

    FileView {
        path: root.dir + "/compat/plugins.json"
        watchChanges: false
        printErrors: true
        onLoaded: root.load(text())
    }
}
