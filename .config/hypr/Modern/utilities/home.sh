#!/bin/bash
set -uo pipefail

DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/home-screen"

# The shell stays resident and hidden, so opening is an IPC call rather than a launch.
qs -p "$DIR" ipc call home toggle 2>/dev/null && exit 0

qs -p "$DIR" --daemonize >/dev/null 2>&1
for _ in $(seq 1 60); do
    sleep 0.05
    qs -p "$DIR" ipc call home open 2>/dev/null && exit 0
done
