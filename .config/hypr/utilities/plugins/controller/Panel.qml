// omarchy-controller: game controllers in the bar.
//
// The bar icon shows whether a controller is connected (and turns urgent on
// low battery). Its panel lists connected controllers with player number,
// connection and battery, draws a map of the selected controller that lights
// up live as you press buttons, and pairs new controllers over Bluetooth with
// per-brand instructions.
//
// Controller detection and live input come from bin/omarchy-controller,
// which only reads sysfs and /dev/input. Pairing goes through Omarchy's own
// omarchy-bluetooth-device helper, which also trusts the controller so it
// reconnects by itself when you press its home button.

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Layouts.js" as Layouts
import "components"

Panel {
  id: root
  moduleName: "avb7.omarchy-controller"
  ipcTarget: "avb7.omarchy-controller"
  // Own IPC handler below, for the extra pair / showMap / simulate methods.
  manageIpc: false

  readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("bin/omarchy-controller")).replace(/^(file|qs):\/\//, ""))
  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
  readonly property string ff: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(fg, 1.45)

  // Status colours are fixed on purpose rather than taken from the theme:
  // in a monochrome theme "urgent" can be a grey that reads as "off".
  readonly property color onColor: "#4fbf5a"
  readonly property color busyColor: "#e3b341"
  readonly property color lowColor: "#e0566a"
  readonly property color offColor: Qt.rgba(fg.r, fg.g, fg.b, 0.35)

  // ------------------------------------------------------------ controllers

  property var controllers: []
  property var hints: []
  property bool loaded: false
  // Identity -> true once a low-battery warning went out for it.
  property var batteryWarned: ({})
  // Set a few seconds after the first snapshot. Warnings wait for it: an
  // update reloads the widget several times in a row, and every fresh
  // instance would otherwise warn about the same battery again.
  property bool settled: false

  Timer {
    interval: 4000
    running: root.loaded && !root.settled
    onTriggered: {
      root.settled = true
      root.checkBatteries(root.controllers)
    }
  }

  readonly property bool lowBattery: {
    for (var i = 0; i < controllers.length; i++) {
      var b = controllers[i].battery
      if (b && !b.charging && b.percent <= 15) return true
    }
    return false
  }

  // Every bar (one per monitor) runs this widget; only the first one speaks,
  // so a connect doesn't produce one notification per screen.
  function isLeader() {
    if (!bar || typeof bar.moduleWidgets !== "function") return true
    var items = bar.moduleWidgets(moduleName)
    return !items || items.length === 0 || items[0] === root
  }

  function notify(title, body) {
    Quickshell.execDetached(["notify-send", "-a", "Controllers", "-i", "input-gaming", title, body || ""])
  }

  function absorb(line) {
    var data
    try {
      data = JSON.parse(line)
    } catch (e) {
      return
    }
    var next = data.controllers || []
    if (root.loaded && root.isLeader()) {
      var changes = Layouts.diff(root.controllers, next)
      for (var a = 0; a < changes.added.length; a++) {
        var added = changes.added[a]
        root.notify(added.name + " connected", Layouts.controllerMeta(added))
      }
      for (var r = 0; r < changes.removed.length; r++) {
        var gone = changes.removed[r]
        root.notify(gone.name + " disconnected", gone.connection === "bluetooth" ? (Layouts.RECONNECT[gone.brand] || "") : "")
      }
    }
    root.checkBatteries(next)
    root.controllers = next
    root.hints = data.hints || []
    root.loaded = true
  }

  function checkBatteries(list) {
    var warned = {}
    for (var k in root.batteryWarned) warned[k] = root.batteryWarned[k]
    for (var i = 0; i < list.length; i++) {
      var c = list[i]
      var id = Layouts.identity(c)
      var b = c.battery
      if (!b) continue
      if (b.charging || b.percent > 25) {
        delete warned[id]
      } else if (b.percent <= 15 && !warned[id] && root.settled) {
        warned[id] = true
        if (root.isLeader()) root.notify(c.name + " battery low", b.percent + "% left · Player " + c.player)
      }
    }
    root.batteryWarned = warned
  }

  Process {
    id: watchProc
    command: [root.helper, "watch"]
    running: true
    stdout: SplitParser {
      onRead: function(line) { root.absorb(line) }
    }
    onExited: watchRestart.restart()
  }

  Timer {
    id: watchRestart
    interval: 3000
    onTriggered: if (!watchProc.running) watchProc.running = true
  }

  // --------------------------------------------------------------- the map

  // Which connected controller the map follows, and a layout picked by hand
  // from the chips ("" = the selected controller's own layout).
  property string selectedId: ""
  property string pickedKind: ""

  readonly property var selected: {
    for (var i = 0; i < controllers.length; i++) {
      if (Layouts.identity(controllers[i]) === selectedId) return controllers[i]
    }
    return controllers.length > 0 ? controllers[0] : null
  }
  readonly property string mapKind: pickedKind !== "" ? pickedKind : (selected ? selected.kind : "dualsense")

  // Live button state streamed from the selected controller while the panel
  // is open. It never grabs the device, so games keep working.
  property var liveKeys: ({})
  property var liveAxes: ({})
  property string liveState: "idle"   // idle | starting | live | permission | gone
  readonly property string liveNode: opened && selected && selected.readable ? selected.node : ""

  onLiveNodeChanged: restartLive()

  function restartLive() {
    liveProc.running = false
    root.liveKeys = ({})
    root.liveAxes = ({})
    if (root.liveNode === "") {
      root.liveState = "idle"
      return
    }
    root.liveState = "starting"
    liveProc.command = [root.helper, "events", root.liveNode]
    Qt.callLater(function() { if (root.liveNode !== "") liveProc.running = true })
  }

  function merged(base, changes) {
    var out = {}
    for (var k in base) out[k] = base[k]
    for (var c in changes) out[c] = changes[c]
    return out
  }

  function absorbLive(line) {
    var data
    try {
      data = JSON.parse(line)
    } catch (e) {
      return
    }
    if (data.ready) { root.liveState = "live"; return }
    if (data.error) { root.liveState = data.error === "permission" ? "permission" : "gone"; return }
    if (data.k) root.liveKeys = root.merged(root.liveKeys, data.k)
    if (data.a) root.liveAxes = root.merged(root.liveAxes, data.a)
  }

  Process {
    id: liveProc
    stdout: SplitParser {
      onRead: function(line) { root.absorbLive(line) }
    }
  }

  readonly property string mapStatus: {
    var title = Layouts.layoutFor(root.mapKind).title
    if (!root.selected) return "Showing the " + title + " layout. Connect a controller to test its buttons."
    if (root.liveState === "permission" || !root.selected.readable) return "Can't read " + root.selected.name + "'s buttons (no permission)."
    if (root.liveState === "live") return "Press any button on " + root.selected.name + " to see it light up."
    if (root.liveState === "gone") return root.selected.name + " stopped responding."
    return "Connecting to " + root.selected.name + "…"
  }

  // The row's second line, with a low battery in red. Every piece is a
  // number or a fixed word from the helper, never a device name, so the
  // markup can't be injected.
  function metaText(c) {
    var text = "Player " + Number(c.player) + " · " + Layouts.connectionLabel(c.connection)
    var b = c.battery
    if (!b) return text
    var pct = Number(b.percent) + "%" + (b.charging ? " charging" : "")
    var low = !b.charging && b.percent <= 15
    return text + " · " + (low ? "<font color=\"" + root.lowColor + "\">" + pct + " · low</font>" : pct)
  }

  function cycleController(delta) {
    if (controllers.length === 0) return
    var index = Math.max(0, controllers.indexOf(selected))
    index = (index + delta + controllers.length) % controllers.length
    selectedId = Layouts.identity(controllers[index])
    pickedKind = ""
  }

  function cycleKind(delta) {
    var kinds = Layouts.KINDS.map(function(k) { return k.value })
    var index = (kinds.indexOf(mapKind) + delta + kinds.length) % kinds.length
    pickKind(kinds[index])
  }

  function pickKind(kind) {
    pickedKind = selected && selected.kind === kind ? "" : kind
  }

  // ------------------------------------------------------------- Bluetooth

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var btDevices: Bluetooth.devices ? Bluetooth.devices.values : []
  property bool pairing: false
  // Address -> "pairing" | "connecting" | "forgetting" while BlueZ catches up.
  property var pendingActions: ({})

  function deviceRow(d) {
    var name = String(d.name || d.deviceName || "")
    return {
      address: String(d.address || ""),
      name: name || "Controller",
      brand: Layouts.brandFromName(name),
      connected: !!d.connected,
      known: !!(d.paired || d.bonded || d.trusted)
    }
  }

  function controllerRows(wantKnown) {
    var rows = []
    for (var i = 0; i < btDevices.length; i++) {
      var d = btDevices[i]
      if (!d || d.connected) continue
      var icon = d.icon !== undefined ? d.icon : ""
      if (!Layouts.isControllerDevice(d.name || d.deviceName, icon)) continue
      var row = deviceRow(d)
      if (row.known === wantKnown) rows.push(row)
    }
    return rows
  }

  readonly property var pairedRows: controllerRows(true)
  readonly property var foundRows: pairing ? controllerRows(false) : []

  function deviceFor(address) {
    for (var i = 0; i < btDevices.length; i++) {
      if (btDevices[i] && btDevices[i].address === address) return btDevices[i]
    }
    return null
  }

  function setPending(address, action) {
    var next = merged(pendingActions, {})
    if (action) next[address] = action
    else delete next[address]
    pendingActions = next
    if (action) pendingTimeout.restart()
  }

  function deviceAction(action, address, pending) {
    if (!/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(address)) return
    setPending(address, pending)
    Quickshell.execDetached(["omarchy-bluetooth-device", action, address])
  }

  onBtDevicesChanged: {
    var next = merged(pendingActions, {})
    var changed = false
    for (var address in next) {
      var d = deviceFor(address)
      var action = next[address]
      if ((action !== "forgetting" && d && d.connected) || (action === "forgetting" && (!d || !(d.paired || d.bonded || d.trusted)))) {
        delete next[address]
        changed = true
      }
    }
    if (changed) pendingActions = next
  }

  Timer {
    id: pendingTimeout
    interval: 25000
    onTriggered: root.pendingActions = ({})
  }

  function startPairing() {
    pairing = true
    if (adapter && !adapter.enabled) Quickshell.execDetached(["omarchy-bluetooth-power", "on"])
    open()
  }

  // Discovery runs only while the pairing view is open. Same care as
  // Omarchy's Bluetooth panel: BlueZ holds the scan for this D-Bus client,
  // so it must be stopped explicitly or the radio keeps scanning (and
  // Bluetooth audio stutters) until the shell restarts.
  property bool owesDiscoveryStop: false
  readonly property bool wantsDiscovery: opened && pairing

  function scanningSibling() {
    if (!bar || typeof bar.moduleWidgets !== "function") return null
    var items = bar.moduleWidgets(moduleName)
    for (var i = 0; i < items.length; i++) {
      if (items[i] && items[i] !== root && items[i].wantsDiscovery === true) return items[i]
    }
    return null
  }

  Timer {
    interval: 1000
    repeat: true
    triggeredOnStart: true
    running: root.wantsDiscovery && root.adapter !== null && root.adapter.enabled && !root.adapter.discovering
    onTriggered: {
      root.owesDiscoveryStop = true
      root.adapter.discovering = true
    }
  }

  Timer {
    interval: 1000
    repeat: true
    property int attempts: 0
    running: !root.wantsDiscovery && root.owesDiscoveryStop && root.adapter !== null && root.adapter.discovering === true
    onRunningChanged: if (running) attempts = 0
    onTriggered: {
      var sibling = root.scanningSibling()
      if (sibling) {
        sibling.owesDiscoveryStop = true
        root.owesDiscoveryStop = false
        return
      }
      attempts += 1
      if (attempts > 3) { root.owesDiscoveryStop = false; return }
      root.adapter.discovering = false
    }
  }

  Connections {
    target: root.adapter
    function onDiscoveringChanged() {
      if (!root.adapter.discovering) root.owesDiscoveryStop = false
    }
  }

  Component.onDestruction: {
    liveProc.running = false
    watchProc.running = false
    if (!owesDiscoveryStop) return
    var items = bar && typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : []
    for (var i = 0; i < items.length; i++) {
      if (items[i] && items[i] !== root) { items[i].owesDiscoveryStop = true; return }
    }
    if (adapter !== null && adapter.discovering) adapter.discovering = false
  }

  onOpenedChanged: if (!opened) pairing = false

  // Only Omarchy's own installers may be launched from a hint.
  function runHint(hint) {
    if (!hint || !/^omarchy-install-[a-z0-9-]+$/.test(hint.action || "")) return
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", hint.action])
    close()
  }

  // -------------------------------------------------------------------- IPC

  IpcHandler {
    target: "avb7.omarchy-controller"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    // Open straight into pairing.
    function pair(): void { root.startPairing() }
    // Open on a given layout: dualsense, dualshock4, xbox, switch-pro, generic.
    function showMap(kind: string): void {
      root.pickKind(kind)
      root.open()
    }
    // Feed the map a line of `omarchy-controller events` output, to check
    // the drawing without a controller, e.g. '{"k":{"304":1}}'.
    function simulate(line: string): void { root.absorbLive(line) }
  }

  // ---------------------------------------------------------------- the bar

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Layouts.BAR_GLYPH
    dimmed: root.loaded && root.controllers.length === 0
    active: root.lowBattery
    activeColor: root.lowColor
    onPressed: function(b) {
      if (b === Qt.RightButton) root.startPairing()
      else root.toggle()
    }
  }

  // Green while a controller is connected, yellow while pairing or
  // connecting one. Nothing when idle: the dimmed icon already says so.
  readonly property string barDot: {
    for (var address in pendingActions) return "busy"
    if (pairing) return "busy"
    return controllers.length > 0 ? "on" : ""
  }

  StatusDot {
    visible: root.barDot !== ""
    status: root.barDot === "" ? "off" : root.barDot
    width: Style.space(6)
    x: button.x + button.width / 2 + Style.space(5)
    y: button.y + button.height / 2 - Style.space(9)
    z: 2
  }

  // -------------------------------------------------------------- the panel

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.cycleController(dy)
        else if (dx !== 0) root.cycleKind(dx)
      }
      onActivateRequested: root.pairing = !root.pairing
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "p" || t === "P") root.pairing = !root.pairing
      }

      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: scroller.width
          spacing: Style.space(14)

          // ---------- Hero ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, pairButton.implicitHeight)

            Text {
              id: heroIcon
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: Layouts.BAR_GLYPH
              color: root.fg
              font.family: root.ff
              font.pixelSize: Style.font.display
              opacity: root.controllers.length > 0 ? 1.0 : 0.5
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: pairButton.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: "Controllers"
                color: root.fg
                font.family: root.ff
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Text {
                textFormat: Text.PlainText
                text: root.pairing ? "LOOKING FOR CONTROLLERS"
                    : root.controllers.length === 1 ? "1 CONNECTED"
                    : root.controllers.length > 1 ? root.controllers.length + " CONNECTED"
                    : "NONE CONNECTED"
                color: root.dim
                font.family: root.ff
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
              }
            }

            Button {
              id: pairButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.pairing ? "Done" : "Pair"
              iconText: root.pairing ? "" : "󰂯"
              bordered: true
              foreground: root.fg
              fontFamily: root.ff
              tooltipText: root.pairing ? "Stop looking for controllers" : "Pair a Bluetooth controller (P)"
              onClicked: root.pairing ? (root.pairing = false) : root.startPairing()
            }
          }

          // ---------- Driver hints ----------
          Repeater {
            model: root.hints
            delegate: Rectangle {
              required property var modelData
              width: column.width
              implicitHeight: hintRow.implicitHeight + Style.space(16)
              radius: Style.space(6)
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)
              border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
              border.width: 1

              Row {
                id: hintRow
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(10)

                Text {
                  width: parent.width - (hintButton.visible ? hintButton.width + parent.spacing : 0)
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: modelData.text
                  wrapMode: Text.WordWrap
                  color: root.fg
                  font.family: root.ff
                  font.pixelSize: Style.font.bodySmall
                }
                Button {
                  id: hintButton
                  visible: modelData.actionLabel !== ""
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.actionLabel
                  bordered: true
                  foreground: root.fg
                  fontFamily: root.ff
                  onClicked: root.runHint(modelData)
                }
              }
            }
          }

          // ---------- Connected ----------
          PanelSeparator { foreground: root.fg }

          Column {
            id: connectedList
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "CONNECTED"
              foreground: root.fg
              fontFamily: root.ff
            }

            Repeater {
              model: root.controllers
              delegate: CursorSurface {
                id: row
                required property var modelData
                readonly property bool isSelected: root.selected !== null && Layouts.identity(root.selected) === Layouts.identity(modelData)
                width: connectedList.width
                implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX
                current: isSelected
                hasCursor: rowMouse.containsMouse
                foreground: root.fg

                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.selectedId = Layouts.identity(row.modelData)
                    root.pickedKind = ""
                  }
                }

                StatusDot {
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(14)
                  anchors.verticalCenter: parent.verticalCenter
                  status: "on"
                }

                Row {
                  id: rowContent
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(34)
                  spacing: Style.space(10)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: Layouts.glyphFor(row.modelData.brand)
                    color: root.fg
                    font.family: root.ff
                    font.pixelSize: Style.font.heading
                  }
                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(1)
                    Text {
                      textFormat: Text.PlainText
                      text: row.modelData.name
                      color: root.fg
                      font.family: root.ff
                      font.pixelSize: Style.font.body
                    }
                    Text {
                      textFormat: Text.StyledText
                      text: root.metaText(row.modelData)
                      color: root.dim
                      font.family: root.ff
                      font.pixelSize: Style.font.caption
                    }
                  }
                }
              }
            }

            Text {
              visible: root.controllers.length === 0
              width: parent.width
              textFormat: Text.PlainText
              wrapMode: Text.WordWrap
              text: root.loaded ? "Plug in a controller, or press Pair to connect one over Bluetooth." : "Looking for controllers…"
              color: root.dim
              font.family: root.ff
              font.pixelSize: Style.font.bodySmall
            }
          }

          // ---------- Pairing ----------
          Column {
            id: pairingSection
            visible: root.pairing
            width: parent.width
            spacing: Style.space(8)

            PanelSeparator { foreground: root.fg }

            PanelSectionHeader {
              text: "PAIR A CONTROLLER"
              foreground: root.fg
              fontFamily: root.ff
            }

            Text {
              visible: !root.adapter || !root.adapter.enabled
              width: parent.width
              textFormat: Text.PlainText
              wrapMode: Text.WordWrap
              text: !root.adapter ? "No Bluetooth adapter found." : "Turning Bluetooth on…"
              color: root.dim
              font.family: root.ff
              font.pixelSize: Style.font.bodySmall
            }

            Repeater {
              model: Layouts.PAIRING
              delegate: Row {
                required property var modelData
                width: pairingSection.width
                spacing: Style.space(10)

                Text {
                  id: brandGlyph
                  textFormat: Text.PlainText
                  text: Layouts.glyphFor(modelData.brand)
                  color: root.fg
                  font.family: root.ff
                  font.pixelSize: Style.font.heading
                  width: Style.space(22)
                }
                Text {
                  width: parent.width - brandGlyph.width - parent.spacing
                  textFormat: Text.StyledText
                  text: "<b>" + modelData.title + "</b>  " + modelData.text
                  wrapMode: Text.WordWrap
                  color: root.fg
                  font.family: root.ff
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }

            PanelSectionHeader {
              text: "FOUND"
              foreground: root.fg
              fontFamily: root.ff
              topPadding: Style.space(6)
            }

            Repeater {
              model: root.foundRows
              delegate: DeviceRow {
                width: pairingSection.width
                row: modelData
                status: root.pendingActions[modelData.address] === "pairing" ? "Pairing…" : "Click to pair"
                dotStatus: root.pendingActions[modelData.address] ? "busy" : "off"
                onActivated: root.deviceAction("pair", modelData.address, "pairing")
              }
            }

            Text {
              visible: root.foundRows.length === 0 && root.adapter !== null && root.adapter.enabled
              width: parent.width
              textFormat: Text.PlainText
              wrapMode: Text.WordWrap
              text: "Looking for controllers in pairing mode…"
              color: root.dim
              font.family: root.ff
              font.pixelSize: Style.font.bodySmall
            }
          }

          // ---------- Paired but not connected ----------
          Column {
            id: pairedSection
            visible: !root.pairing && root.pairedRows.length > 0
            width: parent.width
            spacing: Style.space(8)

            PanelSeparator { foreground: root.fg }

            PanelSectionHeader {
              text: "PAIRED"
              foreground: root.fg
              fontFamily: root.ff
            }

            Repeater {
              model: root.pairedRows
              delegate: DeviceRow {
                width: pairedSection.width
                row: modelData
                forgettable: true
                dotStatus: root.pendingActions[modelData.address] ? "busy" : "off"
                status: {
                  var pending = root.pendingActions[modelData.address]
                  if (pending === "connecting") return "Connecting…"
                  if (pending === "forgetting") return "Forgetting…"
                  return Layouts.RECONNECT[modelData.brand] || ""
                }
                onActivated: root.deviceAction("connect", modelData.address, "connecting")
                onForget: root.deviceAction("forget", modelData.address, "forgetting")
              }
            }
          }

          // ---------- Map ----------
          PanelSeparator { foreground: root.fg }

          Item {
            width: parent.width
            implicitHeight: Math.max(mapHeader.implicitHeight, kindPicker.implicitHeight)

            PanelSectionHeader {
              id: mapHeader
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "MAP"
              foreground: root.fg
              fontFamily: root.ff
            }

            ButtonGroup {
              id: kindPicker
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              options: Layouts.KINDS
              value: root.mapKind
              foreground: root.fg
              fontFamily: root.ff
              fontSize: Style.font.caption
              focusable: false
              onChanged: function(v) { root.pickKind(v) }
            }
          }

          ControllerMap {
            width: parent.width
            height: implicitHeight
            kind: root.mapKind
            keys: root.liveKeys
            axes: root.liveAxes
            foreground: root.fg
            fontFamily: root.ff
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: root.mapStatus
            color: root.liveState === "live" ? root.fg : root.dim
            font.family: root.ff
            font.pixelSize: Style.font.bodySmall
          }

          MapLegend {
            width: parent.width
            kind: root.mapKind
            keys: root.liveKeys
            foreground: root.fg
            fontFamily: root.ff
          }

          Text {
            visible: text !== ""
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: Layouts.layoutFor(root.mapKind).note
            color: root.dim
            font.family: root.ff
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  // A Bluetooth controller row: name, a status line, click to act, and an
  // optional forget button.
  component DeviceRow: CursorSurface {
    id: deviceRow
    property var row: ({})
    property string status: ""
    property bool forgettable: false
    property string dotStatus: "off"
    signal activated()
    signal forget()

    implicitHeight: deviceContent.implicitHeight + Style.spacing.rowPaddingX
    hasCursor: deviceMouse.containsMouse
    foreground: root.fg

    MouseArea {
      id: deviceMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: deviceRow.activated()
    }

    Item {
      id: deviceContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      implicitHeight: Math.max(deviceGlyph.implicitHeight, deviceInfo.implicitHeight, forgetButton.implicitHeight)

      Text {
        id: deviceGlyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: Layouts.glyphFor(deviceRow.row.brand)
        color: root.dim
        font.family: root.ff
        font.pixelSize: Style.font.heading
      }

      Column {
        id: deviceInfo
        anchors.left: deviceGlyph.right
        anchors.leftMargin: Style.space(10)
        anchors.right: rowDot.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: deviceRow.row.name || "Controller"
          elide: Text.ElideRight
          color: root.fg
          font.family: root.ff
          font.pixelSize: Style.font.body
        }
        Text {
          width: parent.width
          visible: deviceRow.status !== ""
          textFormat: Text.PlainText
          text: deviceRow.status
          elide: Text.ElideRight
          color: root.dim
          font.family: root.ff
          font.pixelSize: Style.font.caption
        }
      }

      StatusDot {
        id: rowDot
        anchors.right: forgetButton.visible ? forgetButton.left : parent.right
        anchors.rightMargin: forgetButton.visible ? Style.space(10) : Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        status: deviceRow.dotStatus
      }

      PanelActionButton {
        id: forgetButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: deviceRow.forgettable
        iconText: "󰅙"
        tooltipText: "Forget"
        foreground: root.fg
        hoverColor: root.fg
        fontFamily: root.ff
        onClicked: deviceRow.forget()
      }
    }
  }

  // Connection status dot: "on" green, "busy" yellow and pulsing
  // (connecting, pairing, forgetting), "off" grey.
  component StatusDot: Rectangle {
    id: dot
    property string status: "off"
    width: Style.space(9)
    height: width
    radius: width / 2
    color: status === "on" ? root.onColor : status === "busy" ? root.busyColor : root.offColor

    onStatusChanged: if (status !== "busy") opacity = 1

    SequentialAnimation on opacity {
      running: dot.status === "busy"
      loops: Animation.Infinite
      NumberAnimation { to: 0.3; duration: 550; easing.type: Easing.InOutQuad }
      NumberAnimation { to: 1.0; duration: 550; easing.type: Easing.InOutQuad }
    }
  }
}
