#!/bin/bash
set -uo pipefail

# Toggles the app launcher (opens on Home); launcher.sh apps|home|commands|keybinds opens straight to that tab.
DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

if [ -n "${1:-}" ]; then
    call=(tab "$1")
else
    call=(toggle)
fi

# The shell stays resident and hidden, so opening is an IPC call rather than a launch.
qs -p "$DIR" ipc call launcher "${call[@]}" 2>/dev/null && exit 0

qs -p "$DIR" --daemonize >/dev/null 2>&1
[ "${call[0]}" = toggle ] && call=(open)
for _ in $(seq 1 60); do
    sleep 0.05
    qs -p "$DIR" ipc call launcher "${call[@]}" 2>/dev/null && exit 0
done
