// A drawing of one controller layout that lights up as buttons are pressed.
// Pure presentational: give it a kind plus the live key and axis state.

import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../Layouts.js" as Layouts

Item {
  id: map

  property string kind: "dualsense"
  // { "<code>": 0 | 1 } and { "<axis>": value } from `omarchy-controller events`.
  property var keys: ({})
  property var axes: ({})
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property color onAccent: Commons.Color.background
  property string fontFamily: Style.font.family

  readonly property var layout: Layouts.layoutFor(kind)
  readonly property real s: width / 100
  readonly property color line: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.5)
  readonly property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
  readonly property color caption: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.6)
  readonly property real stroke: Math.max(1, s * 0.3)
  // The highlight for a held button: the theme accent when it has some
  // colour, else the text colour (a grey accent would barely show).
  readonly property color lit: accent.hslSaturation > 0.25 ? accent : foreground

  implicitHeight: width * 0.66

  function down(code) {
    return code !== undefined && map.keys[String(code)] === 1
  }
  function axis(code) {
    var v = map.axes[String(code)]
    return v === undefined ? 0 : v
  }
  function elementsOf(kind) {
    return map.layout.elements.filter(function(e) { return e.kind === kind })
  }

  onKindChanged: body.requestPaint()
  onWidthChanged: body.requestPaint()
  onForegroundChanged: body.requestPaint()

  Canvas {
    id: body
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.save()
      ctx.scale(map.s, map.s)
      ctx.beginPath()
      var path = Layouts.BODY
      for (var i = 0; i < path.length; i++) {
        var p = path[i]
        if (p[0] === "M") ctx.moveTo(p[1], p[2])
        else if (p[0] === "C") ctx.bezierCurveTo(p[1], p[2], p[3], p[4], p[5], p[6])
        else ctx.closePath()
      }
      ctx.fillStyle = map.faint
      ctx.fill()
      ctx.lineWidth = map.stroke / map.s
      ctx.strokeStyle = map.line
      ctx.stroke()
      ctx.restore()
    }
  }

  // ---------------------------------------------------- triggers, bumpers

  Repeater {
    model: map.elementsOf("trigger")
    delegate: Rectangle {
      required property var modelData
      readonly property real value: {
        var v = map.down(modelData.code) ? 1 : 0
        for (var i = 0; i < modelData.axes.length; i++) v = Math.max(v, map.axis(modelData.axes[i]))
        return v
      }
      x: modelData.x * map.s
      y: modelData.y * map.s
      width: modelData.w * map.s
      height: modelData.h * map.s
      radius: height / 2
      color: "transparent"
      border.color: map.line
      border.width: map.stroke
      clip: true

      Text {
        id: triggerLabel
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: parent.modelData.label
        color: map.foreground
        font.family: map.fontFamily
        font.pixelSize: Math.max(8, parent.height * 0.62)
        font.bold: true
      }
      // The fill carries its own copy of the label in the dark ink, clipped
      // to the fill, so a half-pulled trigger reads "L2" in two tones rather
      // than hiding half of it.
      Rectangle {
        width: parent.width * parent.value
        height: parent.height
        radius: parent.radius
        color: map.lit
        visible: parent.value > 0.02
        clip: true

        Text {
          x: triggerLabel.x
          y: triggerLabel.y
          textFormat: Text.PlainText
          text: triggerLabel.text
          color: map.onAccent
          font: triggerLabel.font
        }
      }
    }
  }

  Repeater {
    model: map.elementsOf("shoulder")
    delegate: Rectangle {
      required property var modelData
      readonly property bool pressed: map.down(modelData.code)
      x: modelData.x * map.s
      y: modelData.y * map.s
      width: modelData.w * map.s
      height: modelData.h * map.s
      radius: map.s * 1.2
      color: pressed ? map.lit : "transparent"
      border.color: map.line
      border.width: map.stroke

      Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: parent.modelData.label
        color: parent.pressed ? map.onAccent : map.foreground
        font.family: map.fontFamily
        font.pixelSize: Math.max(8, parent.height * 0.62)
        font.bold: true
      }
    }
  }

  // ------------------------------------------------------------- touchpad

  Repeater {
    model: map.elementsOf("pad")
    delegate: Rectangle {
      required property var modelData
      x: modelData.x * map.s
      y: modelData.y * map.s
      width: modelData.w * map.s
      height: modelData.h * map.s
      radius: map.s * 1.5
      color: "transparent"
      border.color: map.line
      border.width: map.stroke

      Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: parent.modelData.label
        color: map.caption
        font.family: map.fontFamily
        font.pixelSize: Math.max(8, map.s * 2.1)
      }
    }
  }

  // ---------------------------------------------------------------- d-pad

  Repeater {
    model: map.elementsOf("dpad")
    delegate: Item {
      id: pad
      required property var modelData
      readonly property real arm: modelData.size * map.s / 3
      // Not up/down/left/right: Item already has FINAL left/right anchor lines.
      readonly property bool pressUp: map.down(modelData.up) || map.axis(modelData.hatY) < 0
      readonly property bool pressDown: map.down(modelData.down) || map.axis(modelData.hatY) > 0
      readonly property bool pressLeft: map.down(modelData.left) || map.axis(modelData.hatX) < 0
      readonly property bool pressRight: map.down(modelData.right) || map.axis(modelData.hatX) > 0
      x: (modelData.x - modelData.size / 2) * map.s
      y: (modelData.y - modelData.size / 2) * map.s
      width: modelData.size * map.s
      height: width

      Repeater {
        model: [
          { col: 1, row: 0, on: "pressUp" }, { col: 2, row: 1, on: "pressRight" },
          { col: 1, row: 2, on: "pressDown" }, { col: 0, row: 1, on: "pressLeft" }, { col: 1, row: 1, on: "" }
        ]
        delegate: Rectangle {
          required property var modelData
          readonly property bool pressed: modelData.on !== "" && pad[modelData.on]
          x: modelData.col * pad.arm
          y: modelData.row * pad.arm
          width: pad.arm
          height: pad.arm
          radius: map.s * 0.6
          color: pressed ? map.lit : (modelData.on === "" ? map.faint : "transparent")
          border.color: modelData.on === "" ? "transparent" : map.line
          border.width: map.stroke
        }
      }
    }
  }

  // --------------------------------------------------------------- sticks

  Repeater {
    model: map.elementsOf("stick")
    delegate: Rectangle {
      id: well
      required property var modelData
      readonly property real r: modelData.r * map.s
      readonly property bool pressed: map.down(modelData.code)
      x: modelData.x * map.s - r
      y: modelData.y * map.s - r
      width: r * 2
      height: width
      radius: r
      color: "transparent"
      border.color: map.line
      border.width: map.stroke

      Rectangle {
        readonly property real cap: well.r * 0.52
        width: cap * 2
        height: width
        radius: cap
        x: well.r - cap + map.axis(well.modelData.axes[0]) * well.r * 0.48
        y: well.r - cap + map.axis(well.modelData.axes[1]) * well.r * 0.48
        color: well.pressed ? map.lit : map.faint
        border.color: map.line
        border.width: map.stroke

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: well.modelData.label
          color: well.pressed ? map.onAccent : map.caption
          font.family: map.fontFamily
          font.pixelSize: Math.max(8, map.s * 2.1)
        }
      }
    }
  }

  // --------------------------------------------------------- face buttons

  Repeater {
    model: map.elementsOf("face")
    delegate: Rectangle {
      id: face
      required property var modelData
      readonly property bool pressed: map.down(modelData.code)
      readonly property color ink: pressed ? map.onAccent : (modelData.tint !== "" ? modelData.tint : map.foreground)
      x: (modelData.x - modelData.r) * map.s
      y: (modelData.y - modelData.r) * map.s
      width: modelData.r * 2 * map.s
      height: width
      radius: width / 2
      color: pressed ? (modelData.tint !== "" ? modelData.tint : map.lit) : "transparent"
      border.color: map.line
      border.width: map.stroke

      onInkChanged: symbol.requestPaint()

      Text {
        anchors.centerIn: parent
        visible: face.modelData.symbol === ""
        textFormat: Text.PlainText
        text: face.modelData.label
        color: face.ink
        font.family: map.fontFamily
        font.pixelSize: Math.max(8, face.height * 0.5)
        font.bold: true
      }

      // PlayStation symbols are drawn, not typed, so they look right in any font.
      Canvas {
        id: symbol
        anchors.fill: parent
        visible: face.modelData.symbol !== ""
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var w = width, h = height, m = w * 0.3
          ctx.strokeStyle = face.ink
          ctx.lineWidth = Math.max(1.2, w * 0.09)
          ctx.lineCap = "round"
          ctx.lineJoin = "round"
          ctx.beginPath()
          var kind = face.modelData.symbol
          if (kind === "cross") {
            ctx.moveTo(m, m); ctx.lineTo(w - m, h - m)
            ctx.moveTo(w - m, m); ctx.lineTo(m, h - m)
          } else if (kind === "circle") {
            ctx.arc(w / 2, h / 2, w / 2 - m, 0, Math.PI * 2)
          } else if (kind === "square") {
            ctx.rect(m, m, w - 2 * m, h - 2 * m)
          } else if (kind === "triangle") {
            ctx.moveTo(w / 2, m * 0.85)
            ctx.lineTo(w - m * 0.85, h - m * 1.05)
            ctx.lineTo(m * 0.85, h - m * 1.05)
            ctx.closePath()
          }
          ctx.stroke()
        }
      }
    }
  }

  // -------------------------------------------------- small center buttons

  Repeater {
    model: map.elementsOf("pill")
    delegate: Item {
      id: pill
      required property var modelData
      readonly property bool pressed: map.down(modelData.code)
      x: modelData.x * map.s
      y: modelData.y * map.s
      width: modelData.w * map.s
      height: modelData.h * map.s

      Rectangle {
        anchors.fill: parent
        radius: pill.modelData.square ? map.s * 0.7 : Math.min(width, height) / 2
        color: pill.pressed ? map.lit : "transparent"
        border.color: map.line
        border.width: map.stroke
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: map.s * 0.3
        visible: pill.modelData.label !== ""
        textFormat: Text.PlainText
        text: pill.modelData.label
        color: pill.pressed ? map.lit : map.caption
        font.family: map.fontFamily
        font.pixelSize: Math.max(8, map.s * 1.9)
      }
    }
  }

  Repeater {
    model: map.elementsOf("round")
    delegate: Rectangle {
      id: round
      required property var modelData
      readonly property bool pressed: map.down(modelData.code)
      x: (modelData.x - modelData.r) * map.s
      y: (modelData.y - modelData.r) * map.s
      width: modelData.r * 2 * map.s
      height: width
      radius: width / 2
      color: pressed ? map.lit : "transparent"
      border.color: map.line
      border.width: map.stroke

      Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: round.modelData.label
        color: round.pressed ? map.onAccent : map.foreground
        font.family: map.fontFamily
        font.pixelSize: Math.max(8, round.height * (round.modelData.glyph ? 0.62 : 0.55))
        font.bold: !round.modelData.glyph
      }
    }
  }
}
