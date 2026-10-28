import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.liambateman.countdown"

  readonly property var countdownService: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property var featured: countdownService ? countdownService.featuredEvent : null
  readonly property bool notificationsEnabled: countdownService
    ? countdownService.notificationsEnabled
    : Model.boolSetting(setting("notificationsEnabled", true), true)
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.anchorItem = trigger
    target.hostWidget = root
    target.countdownService = root.countdownService
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }

  function updateSetting(name, value) {
    var entry = { id: moduleName }
    for (var key in settings) if (key !== "id") entry[key] = settings[key]
    entry[name] = value
    settings = entry
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, entry)
  }

  function toggleNotifications() {
    updateSetting("notificationsEnabled", !notificationsEnabled)
  }

  implicitWidth: trigger.implicitWidth
  implicitHeight: trigger.implicitHeight

  onBarChanged: injectPanel()
  onCountdownServiceChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: trigger
    anchors.fill: parent
    bar: root.bar
    text: root.featured
      ? root.featured.icon + "  " + Model.compactTitle(root.featured.title, 20) + " · " + root.featured.relative
      : "󰔛  Countdown"
    dimmed: !root.notificationsEnabled
    tooltipText: root.featured
      ? root.featured.title + "\n" + root.featured.detail + (root.notificationsEnabled ? "" : "\nNotifications paused")
      : "Add a holiday, deadline, birthday, or important date"

    onPressed: function(button) {
      if (button === Qt.MiddleButton) root.toggleNotifications()
      else root.toggle()
    }
  }
}
