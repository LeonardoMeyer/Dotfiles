#!/bin/bash
set -uo pipefail

DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/settings"

# The monitor under the cursor (not just the focused one), in layout coordinates: a rotated
# monitor swaps width and height, and scale shrinks both.
SCREEN="$(python3 -c '
import json, subprocess
run = lambda *a: json.loads(subprocess.run(["hyprctl", "-j", *a], capture_output=True, text=True).stdout)
pos = run("cursorpos")
for m in run("monitors"):
    w, h = (m["height"], m["width"]) if m["transform"] % 2 else (m["width"], m["height"])
    if m["x"] <= pos["x"] < m["x"] + w / m["scale"] and m["y"] <= pos["y"] < m["y"] + h / m["scale"]:
        print(m["name"])
        break
' 2>/dev/null)"

# The shell stays resident and hidden, so opening is an IPC call rather than a launch.
# Plain toggle/open is the fallback for a style whose panel predates the per-monitor calls.
qs -p "$DIR" ipc call settings toggleOn "$SCREEN" 2>/dev/null && exit 0
qs -p "$DIR" ipc call settings toggle 2>/dev/null && exit 0

qs -p "$DIR" --daemonize >/dev/null 2>&1
for _ in $(seq 1 60); do
    sleep 0.05
    qs -p "$DIR" ipc call settings openOn "$SCREEN" 2>/dev/null && exit 0
    qs -p "$DIR" ipc call settings open 2>/dev/null && exit 0
done
