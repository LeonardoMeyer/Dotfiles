import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  visible: false
  width: 0
  height: 0

  property var shell: null
  property double nowMs: Date.now()
  property var events: []
  property var fired: ({})
  property bool hydrated: false
  property var notificationQueue: []
  property string lastError: ""

  readonly property string pluginId: "io.github.liambateman.countdown"
  readonly property var settings: settingsEntry()
  readonly property bool notificationsEnabled: Model.boolSetting(settings.notificationsEnabled, true)
  readonly property var sortedEvents: Model.sortedEventViews(events, nowMs)
  readonly property var featuredEvent: Model.featuredEventView(events, persisted.pinnedId, nowMs)
  readonly property string pinnedId: persisted.pinnedId

  PersistentProperties {
    id: persisted
    reloadableId: "io-github-liambateman-countdown"
    property string eventsJson: "[]"
    property string firedJson: "{}"
    property string pinnedId: ""
  }

  function settingsEntry() {
    var config = shell && shell.shellConfig ? shell.shellConfig : null
    if (!config) return ({})

    var layout = config.bar && config.bar.layout ? config.bar.layout : null
    var sections = ["left", "center", "right"]
    if (layout) {
      for (var s = 0; s < sections.length; s++) {
        var entries = layout[sections[s]]
        if (!Array.isArray(entries)) continue
        for (var i = 0; i < entries.length; i++) {
          if (entries[i] && String(entries[i].id || "") === pluginId) return entries[i]
        }
      }
    }

    var plugins = Array.isArray(config.plugins) ? config.plugins : []
    for (var p = 0; p < plugins.length; p++) {
      if (plugins[p] && String(plugins[p].id || "") === pluginId) return plugins[p]
    }
    return ({})
  }

  function parseObject(raw) {
    try {
      var parsed = JSON.parse(String(raw || "{}"))
      return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : ({})
    } catch (e) {
      return ({})
    }
  }

  function hydrate() {
    nowMs = Date.now()
    events = Model.hydrateEvents(persisted.eventsJson, nowMs)
    fired = parseObject(persisted.firedJson)
    hydrated = true
    checkNotifications()
  }

  function persistEvents(next) {
    events = next
    persisted.eventsJson = JSON.stringify(next)
  }

  function persistFired(next) {
    fired = next
    persisted.firedJson = JSON.stringify(next)
  }

  function newId() {
    return "event-" + Date.now() + "-" + Math.floor(Math.random() * 1000000)
  }

  function upsertEvent(input) {
    var now = Date.now()
    var source = input || {}
    var existing = null
    for (var i = 0; i < events.length; i++) {
      if (source.id && events[i].id === source.id) {
        existing = events[i]
        break
      }
    }

    source.id = source.id || newId()
    source.createdAt = existing ? existing.createdAt : now
    source.armedAt = now
    var normalized = Model.normalizeEvent(source, now)
    if (!normalized.ok) {
      lastError = normalized.error
      return normalized
    }

    var next = []
    var replaced = false
    for (var j = 0; j < events.length; j++) {
      if (events[j].id === normalized.event.id) {
        next.push(normalized.event)
        replaced = true
      } else {
        next.push(events[j])
      }
    }
    if (!replaced) next.push(normalized.event)

    var cleanedFired = {}
    for (var key in fired) {
      if (key.indexOf(normalized.event.id + "|") !== 0) cleanedFired[key] = fired[key]
    }
    persistFired(cleanedFired)
    persistEvents(next)
    lastError = ""
    nowMs = now
    return { ok: true, event: normalized.event, error: "" }
  }

  function deleteEvent(id) {
    var next = []
    for (var i = 0; i < events.length; i++) if (events[i].id !== id) next.push(events[i])
    if (next.length === events.length) return

    var cleanedFired = {}
    for (var key in fired) if (key.indexOf(id + "|") !== 0) cleanedFired[key] = fired[key]
    persistFired(cleanedFired)
    persistEvents(next)
    if (persisted.pinnedId === id) persisted.pinnedId = ""
    nowMs = Date.now()
  }

  function togglePinned(id) {
    persisted.pinnedId = persisted.pinnedId === id ? "" : id
    nowMs = Date.now()
  }

  function checkNotifications() {
    if (!hydrated) return
    nowMs = Date.now()
    var result = Model.dueNotifications(events, fired, nowMs)
    persistFired(result.fired)
    if (notificationsEnabled && result.notifications.length) {
      notificationQueue = notificationQueue.concat(result.notifications)
      sendNextNotification()
    }
  }

  function sendNextNotification() {
    if (notificationProcess.running || !notificationQueue.length) return
    var notification = notificationQueue[0]
    notificationQueue = notificationQueue.slice(1)
    var body = notification.reached
      ? "The countdown has reached its date.\n" + notification.detail
      : notification.milestone + " remaining\n" + notification.detail
    notificationProcess.command = [
      "notify-send",
      "--app-name=Countdown",
      "--urgency=normal",
      "--expire-time=12000",
      notification.icon + "  " + notification.title,
      body
    ]
    notificationProcess.running = true
  }

  Process {
    id: notificationProcess
    onExited: function(exitCode) {
      if (exitCode !== 0) root.lastError = "notify-send exited with status " + exitCode + "."
      root.sendNextNotification()
    }
  }

  Timer {
    interval: 60 * 1000
    running: root.shell !== null
    repeat: true
    triggeredOnStart: false
    onTriggered: root.checkNotifications()
  }

  onNotificationsEnabledChanged: if (hydrated) checkNotifications()

  Component.onCompleted: Qt.callLater(hydrate)
}
