// Controller maps, pairing instructions and name matching. Pure data and
// functions: no QML, so `node tests/layouts.test.js` can check it.
//
// Map coordinates are in a 100 x 64 box (x right, y down). Button codes are
// the Linux input codes the kernel reports, which are position-based: the
// bottom face button is always BTN_SOUTH, whatever is printed on it.

var BTN = {
  SOUTH: 304, EAST: 305, NORTH: 307, WEST: 308, Z: 309,
  TL: 310, TR: 311, TL2: 312, TR2: 313,
  SELECT: 314, START: 315, MODE: 316, THUMBL: 317, THUMBR: 318,
  DPAD_UP: 544, DPAD_DOWN: 545, DPAD_LEFT: 546, DPAD_RIGHT: 547,
  KEY_RECORD: 167
}

var ABS = { X: 0, Y: 1, Z: 2, RX: 3, RY: 4, RZ: 5, GAS: 9, BRAKE: 10, HAT0X: 16, HAT0Y: 17 }

// The gamepad outline, as cubic Bézier segments.
var BODY = [
  ["M", 24, 12],
  ["C", 36, 9, 64, 9, 76, 12],
  ["C", 86, 14, 92, 18, 94, 27],
  ["C", 97, 41, 98, 55, 90, 61],
  ["C", 85, 65, 79, 61, 76, 56],
  ["C", 72, 51, 64, 50, 50, 50],
  ["C", 36, 50, 28, 51, 24, 56],
  ["C", 21, 61, 15, 65, 10, 61],
  ["C", 2, 55, 3, 41, 6, 27],
  ["C", 8, 18, 14, 14, 24, 12],
  ["Z"]
]

// Shoulders and triggers sit above the body; they are the same on every pad.
function topRow(names) {
  return [
    { id: "lt", kind: "trigger", label: names[2], x: 15, y: 0.5, w: 17, h: 4, axes: [ABS.Z, ABS.BRAKE], code: BTN.TL2 },
    { id: "rt", kind: "trigger", label: names[3], x: 68, y: 0.5, w: 17, h: 4, axes: [ABS.RZ, ABS.GAS], code: BTN.TR2 },
    { id: "lb", kind: "shoulder", label: names[0], x: 16, y: 5.5, w: 15, h: 4, code: BTN.TL },
    { id: "rb", kind: "shoulder", label: names[1], x: 69, y: 5.5, w: 15, h: 4, code: BTN.TR }
  ]
}

function dpad(x, y) {
  return { id: "dpad", kind: "dpad", x: x, y: y, size: 12,
           up: BTN.DPAD_UP, down: BTN.DPAD_DOWN, left: BTN.DPAD_LEFT, right: BTN.DPAD_RIGHT,
           hatX: ABS.HAT0X, hatY: ABS.HAT0Y }
}

function stick(id, label, x, y, axes, code) {
  return { id: id, kind: "stick", label: label, x: x, y: y, r: 6, axes: axes, code: code }
}

// Face buttons around (x, y). `faces` lists north, east, south, west as
// { label | symbol, tint }.
function faceButtons(x, y, faces) {
  var spots = [[0, -7, BTN.NORTH], [7, 0, BTN.EAST], [0, 7, BTN.SOUTH], [-7, 0, BTN.WEST]]
  return spots.map(function(s, i) {
    var f = faces[i]
    return { id: "face" + s[2], kind: "face", x: x + s[0], y: y + s[1], r: 3.6, code: s[2],
             label: f.label || "", symbol: f.symbol || "", tint: f.tint || "" }
  })
}

var LAYOUTS = {
  dualsense: {
    title: "PlayStation 5 (DualSense)",
    elements: topRow(["L1", "R1", "L2", "R2"]).concat(
      [dpad(23, 27)],
      faceButtons(77, 27, [
        { symbol: "triangle", tint: "#3fbf8a" }, { symbol: "circle", tint: "#e0566a" },
        { symbol: "cross", tint: "#5c8fe6" }, { symbol: "square", tint: "#d07ad0" }]),
      [stick("ls", "L3", 37, 40, [ABS.X, ABS.Y], BTN.THUMBL),
       stick("rs", "R3", 63, 40, [ABS.RX, ABS.RY], BTN.THUMBR),
       { id: "pad", kind: "pad", label: "Touchpad", x: 39, y: 14, w: 22, h: 13 },
       { id: "select", kind: "pill", label: "Create", x: 31.5, y: 15, w: 5, h: 3, code: BTN.SELECT },
       { id: "start", kind: "pill", label: "Options", x: 63.5, y: 15, w: 5, h: 3, code: BTN.START },
       { id: "mode", kind: "round", label: "\u{F0414}", glyph: true, x: 50, y: 34, r: 2.8, code: BTN.MODE }]),
    legend: [
      { label: "✕", name: "Cross", maps: "A · confirm", codes: [BTN.SOUTH] },
      { label: "○", name: "Circle", maps: "B · back", codes: [BTN.EAST] },
      { label: "□", name: "Square", maps: "X", codes: [BTN.WEST] },
      { label: "△", name: "Triangle", maps: "Y", codes: [BTN.NORTH] },
      { label: "L1 R1", name: "Bumpers", maps: "LB RB", codes: [BTN.TL, BTN.TR] },
      { label: "L2 R2", name: "Triggers", maps: "LT RT", codes: [BTN.TL2, BTN.TR2] },
      { label: "L3 R3", name: "Stick clicks", maps: "LS RS", codes: [BTN.THUMBL, BTN.THUMBR] },
      { label: "Create", name: "Create", maps: "View · Back", codes: [BTN.SELECT] },
      { label: "Options", name: "Options", maps: "Menu · Start", codes: [BTN.START] },
      { label: "PS", name: "PS button", maps: "Guide · Steam menu", codes: [BTN.MODE] },
      { label: "Pad", name: "Touchpad", maps: "Mouse in Steam", codes: [] }
    ],
    note: ""
  },

  xbox: {
    title: "Xbox",
    elements: topRow(["LB", "RB", "LT", "RT"]).concat(
      [stick("ls", "LS", 24, 26, [ABS.X, ABS.Y], BTN.THUMBL),
       dpad(37, 40)],
      faceButtons(76, 26, [
        { label: "Y", tint: "#e3b341" }, { label: "B", tint: "#e0566a" },
        { label: "A", tint: "#4fbf5a" }, { label: "X", tint: "#5c8fe6" }]),
      [stick("rs", "RS", 63, 40, [ABS.RX, ABS.RY], BTN.THUMBR),
       { id: "select", kind: "pill", label: "View", x: 39, y: 22, w: 5, h: 3, code: BTN.SELECT },
       { id: "start", kind: "pill", label: "Menu", x: 56, y: 22, w: 5, h: 3, code: BTN.START },
       { id: "mode", kind: "round", label: "\u{F05B9}", glyph: true, x: 50, y: 15.5, r: 3.4, code: BTN.MODE },
       { id: "share", kind: "pill", label: "Share", x: 48, y: 27, w: 4, h: 2.6, code: BTN.KEY_RECORD }]),
    legend: [
      { label: "A", name: "A", maps: "A · confirm", codes: [BTN.SOUTH] },
      { label: "B", name: "B", maps: "B · back", codes: [BTN.EAST] },
      { label: "X", name: "X", maps: "X", codes: [BTN.WEST] },
      { label: "Y", name: "Y", maps: "Y", codes: [BTN.NORTH] },
      { label: "LB RB", name: "Bumpers", maps: "LB RB", codes: [BTN.TL, BTN.TR] },
      { label: "LT RT", name: "Triggers", maps: "LT RT", codes: [BTN.TL2, BTN.TR2] },
      { label: "LS RS", name: "Stick clicks", maps: "LS RS", codes: [BTN.THUMBL, BTN.THUMBR] },
      { label: "View", name: "View", maps: "View · Back", codes: [BTN.SELECT] },
      { label: "Menu", name: "Menu", maps: "Menu · Start", codes: [BTN.START] },
      { label: "Xbox", name: "Xbox button", maps: "Guide · Steam menu", codes: [BTN.MODE] },
      { label: "Share", name: "Share", maps: "Screenshot in Steam", codes: [BTN.KEY_RECORD] }
    ],
    note: ""
  },

  "switch-pro": {
    title: "Nintendo Switch Pro",
    elements: topRow(["L", "R", "ZL", "ZR"]).concat(
      [stick("ls", "LS", 24, 26, [ABS.X, ABS.Y], BTN.THUMBL),
       dpad(37, 40)],
      faceButtons(76, 26, [{ label: "X" }, { label: "A" }, { label: "B" }, { label: "Y" }]),
      [stick("rs", "RS", 63, 40, [ABS.RX, ABS.RY], BTN.THUMBR),
       { id: "select", kind: "round", label: "−", x: 40, y: 18, r: 2.2, code: BTN.SELECT },
       { id: "start", kind: "round", label: "+", x: 60, y: 18, r: 2.2, code: BTN.START },
       { id: "capture", kind: "pill", label: "", square: true, x: 42.5, y: 24.5, w: 3.4, h: 3.4, code: BTN.Z },
       { id: "mode", kind: "round", label: "⌂", x: 56, y: 26.2, r: 2.4, code: BTN.MODE }]),
    legend: [
      { label: "B", name: "B (bottom)", maps: "A · confirm", codes: [BTN.SOUTH] },
      { label: "A", name: "A (right)", maps: "B · back", codes: [BTN.EAST] },
      { label: "Y", name: "Y (left)", maps: "X", codes: [BTN.WEST] },
      { label: "X", name: "X (top)", maps: "Y", codes: [BTN.NORTH] },
      { label: "L R", name: "Bumpers", maps: "LB RB", codes: [BTN.TL, BTN.TR] },
      { label: "ZL ZR", name: "Triggers", maps: "LT RT (on/off)", codes: [BTN.TL2, BTN.TR2] },
      { label: "LS RS", name: "Stick clicks", maps: "LS RS", codes: [BTN.THUMBL, BTN.THUMBR] },
      { label: "−", name: "Minus", maps: "View · Back", codes: [BTN.SELECT] },
      { label: "+", name: "Plus", maps: "Menu · Start", codes: [BTN.START] },
      { label: "⌂", name: "Home", maps: "Guide · Steam menu", codes: [BTN.MODE] },
      { label: "□", name: "Capture", maps: "Screenshot in Steam", codes: [BTN.Z] }
    ],
    note: "Linux maps Nintendo buttons by position, so B (bottom) works as Xbox A."
  },

  generic: {
    title: "Other gamepads",
    elements: topRow(["L1", "R1", "L2", "R2"]).concat(
      [dpad(23, 27)],
      faceButtons(77, 27, [{ label: "N" }, { label: "E" }, { label: "S" }, { label: "W" }]),
      [stick("ls", "L3", 37, 40, [ABS.X, ABS.Y], BTN.THUMBL),
       stick("rs", "R3", 63, 40, [ABS.RX, ABS.RY], BTN.THUMBR),
       { id: "select", kind: "pill", label: "Select", x: 40, y: 20, w: 6, h: 3, code: BTN.SELECT },
       { id: "start", kind: "pill", label: "Start", x: 54, y: 20, w: 6, h: 3, code: BTN.START },
       { id: "mode", kind: "round", label: "", x: 50, y: 30, r: 2.6, code: BTN.MODE }]),
    legend: [
      { label: "S", name: "Bottom", maps: "A · confirm", codes: [BTN.SOUTH] },
      { label: "E", name: "Right", maps: "B · back", codes: [BTN.EAST] },
      { label: "W", name: "Left", maps: "X", codes: [BTN.WEST] },
      { label: "N", name: "Top", maps: "Y", codes: [BTN.NORTH] },
      { label: "L1 R1", name: "Bumpers", maps: "LB RB", codes: [BTN.TL, BTN.TR] },
      { label: "L2 R2", name: "Triggers", maps: "LT RT", codes: [BTN.TL2, BTN.TR2] },
      { label: "L3 R3", name: "Stick clicks", maps: "LS RS", codes: [BTN.THUMBL, BTN.THUMBR] },
      { label: "Select", name: "Select", maps: "View · Back", codes: [BTN.SELECT] },
      { label: "Start", name: "Start", maps: "Menu · Start", codes: [BTN.START] },
      { label: "Home", name: "Home", maps: "Guide · Steam menu", codes: [BTN.MODE] }
    ],
    note: "Buttons are named by position. Steam can remap any of them per game."
  }
}

// DualShock 4: the DualSense layout with Share instead of Create.
LAYOUTS.dualshock4 = {
  title: "PlayStation 4 (DualShock 4)",
  elements: LAYOUTS.dualsense.elements.map(function(e) {
    return e.id === "select" ? Object.assign({}, e, { label: "Share" }) : e
  }),
  legend: LAYOUTS.dualsense.legend.map(function(l) {
    return l.name === "Create" ? Object.assign({}, l, { label: "Share", name: "Share" }) : l
  }),
  note: ""
}

var KINDS = [
  { value: "dualsense", label: "PS5" },
  { value: "dualshock4", label: "PS4" },
  { value: "xbox", label: "Xbox" },
  { value: "switch-pro", label: "Switch" },
  { value: "generic", label: "Other" }
]

function layoutFor(kind) {
  return LAYOUTS[kind] || LAYOUTS.generic
}

// --------------------------------------------------------------- pairing

var PAIRING = [
  { brand: "playstation", title: "PlayStation", text: "Hold PS + Create (PS5) or PS + Share (PS4) until the light bar flashes fast." },
  { brand: "xbox", title: "Xbox", text: "Turn it on, then hold the pair button on top until the Xbox logo flashes fast." },
  { brand: "nintendo", title: "Switch", text: "Hold the small sync button on top (Pro) or on the rail (Joy-Con) until the lights run." },
  { brand: "8bitdo", title: "8BitDo", text: "Turn it on in Bluetooth mode, then hold the pair button for 3 seconds." }
]

var RECONNECT = {
  playstation: "Press the PS button to reconnect.",
  xbox: "Press the Xbox button to reconnect.",
  nintendo: "Press any button to reconnect.",
  "8bitdo": "Turn it on to reconnect.",
  steam: "Turn it on to reconnect.",
  other: "Turn it on to reconnect."
}

// Brand from a Bluetooth name, for devices the kernel hasn't seen yet.
function brandFromName(name) {
  var n = String(name || "").toLowerCase()
  if (n.indexOf("dualsense") >= 0 || n.indexOf("dualshock") >= 0 || n === "wireless controller" || n.indexOf("playstation") >= 0) return "playstation"
  if (n.indexOf("xbox") >= 0) return "xbox"
  if (n.indexOf("pro controller") >= 0 || n.indexOf("joy-con") >= 0 || n.indexOf("nintendo") >= 0) return "nintendo"
  if (n.indexOf("8bitdo") >= 0) return "8bitdo"
  if (n.indexOf("steam") >= 0) return "steam"
  return "other"
}

// Whether a Bluetooth device is a game controller: BlueZ's icon when it has
// one, else the name.
function isControllerDevice(name, icon) {
  if (String(icon || "") === "input-gaming") return true
  if (brandFromName(name) !== "other") return true
  return /gamepad|game ?pad|controller|joystick/i.test(String(name || ""))
}

// Nerd Font (Material Design) glyphs.
var GLYPHS = {
  playstation: "\u{F0414}",
  xbox: "\u{F05B9}",
  nintendo: "\u{F07E1}",
  steam: "\u{F04D3}",
  "8bitdo": "\u{F02B4}",
  other: "\u{F02B4}"
}
var GAMEPAD_GLYPH = "\u{F02B4}"
// The bar and panel icon: a controller silhouette, distinct from the
// gamepad glyph other gaming widgets (like Game Mode) tend to use.
var BAR_GLYPH = "\u{F05BA}"

function glyphFor(brand) {
  return GLYPHS[brand] || GAMEPAD_GLYPH
}

function connectionLabel(connection) {
  if (connection === "usb") return "USB"
  if (connection === "bluetooth") return "Bluetooth"
  return "Wireless"
}

// "Player 1 · Bluetooth · 80%" for a controller row.
function controllerMeta(c) {
  var parts = ["Player " + c.player, connectionLabel(c.connection)]
  if (c.battery) parts.push(c.battery.percent + "%" + (c.battery.charging ? " charging" : ""))
  return parts.join(" · ")
}

// Which controllers appeared or left between two snapshots. Identity is the
// Bluetooth address when there is one, else the device name and node.
function identity(c) {
  return c.address ? "bt:" + c.address : "dev:" + c.deviceName + ":" + c.node
}

function diff(before, after) {
  var was = {}
  var now = {}
  ;(before || []).forEach(function(c) { was[identity(c)] = c })
  ;(after || []).forEach(function(c) { now[identity(c)] = c })
  return {
    added: (after || []).filter(function(c) { return !was[identity(c)] }),
    removed: (before || []).filter(function(c) { return !now[identity(c)] })
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    BTN: BTN, ABS: ABS, BODY: BODY, LAYOUTS: LAYOUTS, KINDS: KINDS, PAIRING: PAIRING, RECONNECT: RECONNECT,
    layoutFor: layoutFor, brandFromName: brandFromName, isControllerDevice: isControllerDevice,
    glyphFor: glyphFor, BAR_GLYPH: BAR_GLYPH, connectionLabel: connectionLabel, controllerMeta: controllerMeta,
    identity: identity, diff: diff
  }
}
