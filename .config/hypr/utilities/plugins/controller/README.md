# omarchy-controller

Console-style game controller support for the Omarchy bar. Plug in or pair a
PlayStation, Xbox, Switch or generic controller and see it in the bar with
its player number and battery. Open the panel for a live map of the
controller that lights up as you press buttons.

<p align="center">
  <img src="screenshot.png" alt="The Controllers panel: a DualSense map with Cross, R1, L2 and d-pad up lit, and a legend of what each button does in games" width="480">
</p>

## What it does

- **Bar icon.** Dimmed when no controller is connected, with a green dot
  while one is and a yellow dot while pairing. It turns red when a
  controller's battery is low. Click for the panel, right-click to pair.
- **Connected controllers.** Each one with its player number, USB or
  Bluetooth, and battery (red at 15% or less). Click one to show its map.
- **Status dots.** Green: connected. Yellow, pulsing: connecting, pairing
  or forgetting. Gray: paired but off, or found and not paired yet. They use
  fixed colors, so they stay readable in monochrome themes.
- **Live controller map.** A drawing of the controller that lights up as you
  press buttons: sticks move, triggers fill, the d-pad and face buttons
  light in their own colours. Pick any layout with the chips: PS5, PS4,
  Xbox, Switch, Other.
- **What each button does in games.** The legend under the map gives every
  button's Xbox-style name, which is what Steam and most games use. For
  example, a PlayStation's ✕ is "A · confirm". On a Switch, the bottom
  button (B) is the one games treat as A, because Linux maps buttons by
  position.
- **Bluetooth pairing.** Press **Pair** to get instructions for each brand
  (for example, hold PS + Create until the light bar flashes) and a list of
  controllers that are in pairing mode. Click one to pair it. Pairing also
  trusts it, so later you just press its PS/Xbox/Home button to reconnect.
  Paired controllers that are switched off are listed with Connect and
  Forget.
- **Popups.** A notification when a controller connects
  ("DualSense connected · Player 1 · Bluetooth · 80%") or disconnects, and
  when its battery drops to 15%.
- **Driver help.** If an Xbox controller is on Bluetooth without the
  `xpadneo` driver, the panel offers **Install**, which runs Omarchy's own
  `omarchy-install-gaming-xbox-controllers` in a terminal. If an Xbox
  Wireless Adapter is plugged in without the `xone` driver, it says so.

## Supported controllers

| Controller | Map | Notes |
|---|---|---|
| DualSense, DualSense Edge | PS5 | USB or Bluetooth |
| DualShock 4 (and older PlayStation pads) | PS4 | USB or Bluetooth |
| Xbox One, Series, 360 | Xbox | USB or Bluetooth. The wireless USB adapter needs `xone` |
| Switch Pro Controller | Switch | USB or Bluetooth |
| Joy-Con, 8BitDo, Steam, other gamepads | Other | Joy-Cons show up one by one |

## Install

```sh
omarchy plugin add https://github.com/avb7/omarchy-controller.git --enable
# or from a local checkout:
omarchy plugin add ~/plugins/omarchy-controller --enable --yes
```

No extra packages: it uses Python 3, `udevadm` and BlueZ, which Omarchy
already ships.

## Keys

In the panel: `j` / `k` (or ↑ / ↓) switch controller, `h` / `l` (or ← / →)
switch map, `P` or `Enter` starts or stops pairing, `Esc` closes.

From a terminal or a key binding:

```sh
omarchy-shell avb7.omarchy-controller toggle
omarchy-shell avb7.omarchy-controller pair          # open straight into pairing
omarchy-shell avb7.omarchy-controller showMap xbox  # dualsense, dualshock4, xbox, switch-pro, generic
```

## How it works

`bin/omarchy-controller` finds controllers in `/sys/class/input`, reads
their batteries from the kernel, and watches `udevadm` for plugs and
unplugs. For the live map it reads the selected controller's
`/dev/input/event*` node while the panel is open. systemd already lets the
logged-in user read game controllers, so no extra group is needed. It never
grabs the device, so games keep getting every press.

Steam Input's virtual copies of your controllers are hidden, so each pad is
listed once. Pairing goes through Omarchy's own `omarchy-bluetooth-device`.

Read-only: no sudo, no network.

## Limits

- It doesn't set the DualSense light bar or player LEDs (that needs root).
- Joy-Cons are listed separately rather than as a pair.

## Tests

```sh
python3 -m unittest discover -s tests   # detection, batteries, hints, live events
node tests/layouts.test.js              # every map and legend
```

To check the map without a controller:

```sh
omarchy-shell avb7.omarchy-controller showMap dualsense
omarchy-shell avb7.omarchy-controller simulate '{"k":{"304":1},"a":{"2":0.6,"17":-1}}'
```

## Remove

```sh
omarchy plugin remove avb7.omarchy-controller
```
