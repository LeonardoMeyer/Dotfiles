// What each button on a layout counts as in games (Xbox naming, which Steam
// and SDL use). A row lights up while its button is held.

import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../Layouts.js" as Layouts

Grid {
  id: legend

  property string kind: "dualsense"
  property var keys: ({})
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property color onAccent: Commons.Color.background
  property string fontFamily: Style.font.family

  readonly property var entries: Layouts.layoutFor(kind).legend
  readonly property color lit: accent.hslSaturation > 0.25 ? accent : foreground

  columns: 2
  columnSpacing: Style.space(14)
  rowSpacing: Style.space(5)

  function held(codes) {
    for (var i = 0; i < codes.length; i++) {
      if (legend.keys[String(codes[i])] === 1) return true
    }
    return false
  }

  Repeater {
    model: legend.entries
    delegate: Row {
      id: entry
      required property var modelData
      readonly property bool active: legend.held(modelData.codes)
      width: (legend.width - legend.columnSpacing) / 2
      spacing: Style.space(8)

      Rectangle {
        id: chip
        width: Math.max(Style.space(44), chipText.implicitWidth + Style.space(10))
        height: chipText.implicitHeight + Style.space(4)
        radius: height / 2
        color: entry.active ? legend.lit : "transparent"
        border.color: Qt.rgba(legend.foreground.r, legend.foreground.g, legend.foreground.b, 0.35)
        border.width: 1

        Text {
          id: chipText
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: entry.modelData.label
          color: entry.active ? legend.onAccent : legend.foreground
          font.family: legend.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Text {
        anchors.verticalCenter: chip.verticalCenter
        width: entry.width - chip.width - entry.spacing
        textFormat: Text.PlainText
        text: entry.modelData.maps
        elide: Text.ElideRight
        color: entry.active ? legend.lit : Qt.darker(legend.foreground, 1.25)
        font.family: legend.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
