import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root
  visible: false
  width: 0
  height: 0

  property var bar: null
  property var anchorItem: null
  property var hostWidget: null
  property var countdownService: null
  property bool opened: false
  property bool editing: false
  property string editingId: ""
  property var formAlerts: Model.DEFAULT_ALERTS.slice()
  property string formError: ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var eventViews: countdownService ? countdownService.sortedEvents : []
  readonly property bool editingText: titleField.activeFocus
    || dateField.activeFocus
    || timeField.activeFocus
    || iconField.activeFocus
  readonly property var alertChoices: [
    { minutes: 43200, label: "30d" },
    { minutes: 10080, label: "7d" },
    { minutes: 1440, label: "1d" },
    { minutes: 60, label: "1h" },
    { minutes: 0, label: "At time" }
  ]

  function open() { opened = true }
  function close() { opened = false; editing = false; formError = "" }
  function toggle() { opened ? close() : open() }

  function beginAdd() {
    editingId = ""
    titleField.text = ""
    dateField.text = Model.defaultDate(Date.now())
    timeField.text = "09:00"
    iconField.text = "󰔛"
    allDaySwitch.checked = true
    yearlySwitch.checked = false
    formAlerts = Model.DEFAULT_ALERTS.slice()
    formError = ""
    editing = true
    Qt.callLater(function() { titleField.forceActiveFocus() })
  }

  function beginEdit(view) {
    var event = view.event
    editingId = event.id
    titleField.text = event.title
    dateField.text = event.date
    timeField.text = event.time
    iconField.text = event.icon
    allDaySwitch.checked = event.allDay
    yearlySwitch.checked = event.yearly
    formAlerts = event.alerts.slice()
    formError = ""
    editing = true
    Qt.callLater(function() { titleField.forceActiveFocus() })
  }

  function toggleAlert(minutes) {
    var next = []
    var found = false
    for (var i = 0; i < formAlerts.length; i++) {
      if (formAlerts[i] === minutes) found = true
      else next.push(formAlerts[i])
    }
    if (!found) next.push(minutes)
    formAlerts = Model.normalizedAlerts(next)
  }

  function saveForm() {
    if (!countdownService) return
    var result = countdownService.upsertEvent({
      id: editingId,
      title: titleField.text,
      date: dateField.text,
      time: timeField.text,
      allDay: allDaySwitch.checked,
      yearly: yearlySwitch.checked,
      icon: iconField.text,
      alerts: formAlerts
    })
    if (!result.ok) {
      formError = result.error
      return
    }
    editing = false
    formError = ""
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.hostWidget || root
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(470))
    contentHeight: popup.fittedContentHeight(Style.space(570))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editingText
      onCloseRequested: root.close()

      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height && !root.editingText
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: content
          width: scroller.width
          spacing: Style.space(12)

        Row {
          width: parent.width
          spacing: Style.space(8)

          Column {
            width: parent.width - actions.implicitWidth - parent.spacing
            spacing: Style.space(2)

            Text {
              text: "Countdown"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: root.eventViews.length === 1 ? "1 important date" : root.eventViews.length + " important dates"
              color: Qt.darker(root.foreground, 1.45)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Row {
            id: actions
            spacing: Style.space(6)

            Button {
              text: root.countdownService && root.countdownService.notificationsEnabled ? "Alerts on" : "Alerts off"
              foreground: root.foreground
              selected: root.countdownService && !root.countdownService.notificationsEnabled
              bordered: true
              focusable: true
              onClicked: if (root.hostWidget) root.hostWidget.toggleNotifications()
            }

            Button {
              text: "+ New"
              foreground: root.foreground
              selected: root.editing && root.editingId === ""
              bordered: true
              focusable: true
              onClicked: root.beginAdd()
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          visible: root.editing
          width: parent.width
          spacing: Style.space(9)

          Text {
            text: root.editingId ? "EDIT COUNTDOWN" : "NEW COUNTDOWN"
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          TextField {
            id: titleField
            width: parent.width
            placeholderText: "Name — e.g. Summer holiday"
            foreground: root.foreground
            font.family: root.fontFamily
            Keys.onReturnPressed: root.saveForm()
            Keys.onEscapePressed: root.editing = false
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            TextField {
              id: dateField
              width: parent.width - timeField.width - iconField.width - parent.spacing * 2
              placeholderText: "YYYY-MM-DD"
              foreground: root.foreground
              font.family: root.fontFamily
            }

            TextField {
              id: timeField
              width: Style.space(86)
              enabled: !allDaySwitch.checked
              placeholderText: "HH:MM"
              foreground: root.foreground
              font.family: root.fontFamily
            }

            TextField {
              id: iconField
              width: Style.space(58)
              placeholderText: "Icon"
              foreground: root.foreground
              font.family: root.fontFamily
              horizontalAlignment: TextInput.AlignHCenter
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(18)

            Row {
              spacing: Style.space(7)
              Text {
                text: "All-day"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
              }
              ToggleSwitch {
                id: allDaySwitch
                checked: true
                foreground: root.foreground
                onToggled: checked = !checked
              }
            }

            Row {
              spacing: Style.space(7)
              Text {
                text: "Repeat yearly"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
              }
              ToggleSwitch {
                id: yearlySwitch
                checked: false
                foreground: root.foreground
                onToggled: checked = !checked
              }
            }
          }

          Text {
            text: "NOTIFY ME"
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Row {
            width: parent.width
            spacing: Style.space(5)

            Repeater {
              model: root.alertChoices
              Button {
                required property var modelData
                text: modelData.label
                foreground: root.foreground
                selected: root.formAlerts.indexOf(modelData.minutes) >= 0
                bordered: true
                focusable: true
                onClicked: root.toggleAlert(modelData.minutes)
              }
            }
          }

          Text {
            visible: root.formError !== ""
            width: parent.width
            text: root.formError
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Row {
            spacing: Style.space(6)
            Button {
              text: root.editingId ? "Save changes" : "Add countdown"
              foreground: root.foreground
              selected: true
              bordered: true
              focusable: true
              onClicked: root.saveForm()
            }
            Button {
              text: "Cancel"
              foreground: root.foreground
              bordered: true
              focusable: true
              onClicked: { root.editing = false; root.formError = "" }
            }
          }

          PanelSeparator { foreground: root.foreground }
        }

        Text {
          visible: !root.editing && root.eventViews.length === 0
          width: parent.width
          text: "No countdowns yet. Add a holiday, deadline, birthday, launch, or anything worth anticipating."
          color: Qt.darker(root.foreground, 1.35)
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Repeater {
          model: root.eventViews

          Rectangle {
            required property var modelData
            width: content.width
            implicitHeight: eventColumn.implicitHeight + Style.space(18)
            radius: Style.cornerRadius
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.045)
            border.width: root.countdownService && root.countdownService.pinnedId === modelData.id ? 1 : 0
            border.color: Color.accent

            Column {
              id: eventColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(5)

              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  text: modelData.icon
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                  width: parent.width - countdownLabel.implicitWidth - Style.space(38)
                  spacing: Style.space(1)

                  Text {
                    width: parent.width
                    text: modelData.title + (modelData.yearly ? "  ↻" : "")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: modelData.detail
                    color: Qt.darker(root.foreground, 1.45)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }

                Text {
                  id: countdownLabel
                  text: modelData.relative
                  color: modelData.past ? Qt.darker(root.foreground, 1.45) : Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Row {
                spacing: Style.space(5)
                Button {
                  text: root.countdownService && root.countdownService.pinnedId === modelData.id ? "Unpin" : "Pin"
                  foreground: root.foreground
                  bordered: true
                  focusable: true
                  onClicked: root.countdownService.togglePinned(modelData.id)
                }
                Button {
                  text: "Edit"
                  foreground: root.foreground
                  bordered: true
                  focusable: true
                  onClicked: root.beginEdit(modelData)
                }
                Button {
                  text: "Delete"
                  foreground: root.foreground
                  bordered: true
                  focusable: true
                  onClicked: root.countdownService.deleteEvent(modelData.id)
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          text: "Dates use your computer’s local time. All-day alerts fire at 09:00. Middle-click the bar widget to pause alerts."
          color: Qt.darker(root.foreground, 1.65)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
        }
      }
    }
  }
}
