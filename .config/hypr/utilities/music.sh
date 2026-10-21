#!/bin/bash
set -uo pipefail

# Toggles the music player (Alt+M); music.sh open|close does just that.
DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
call="${1:-toggle}"

# The shell stays resident and hidden, so opening is an IPC call rather than a launch.
qs -p "$DIR" ipc call music "$call" 2>/dev/null && exit 0

[ "$call" = close ] && exit 0
qs -p "$DIR" --daemonize >/dev/null 2>&1
for _ in $(seq 1 60); do
    sleep 0.05
    qs -p "$DIR" ipc call music open 2>/dev/null && exit 0
done
