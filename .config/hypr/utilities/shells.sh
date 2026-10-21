#!/bin/bash
set -uo pipefail

# Starts or stops the quickshell utilities, all hosted in one process by utilities/shell.qml.
# boot is excluded: it only runs once, launched by startup.lua with its own environment.
UTIL="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

case "${1:-}" in
    start)
        qs -n -p "$UTIL" --daemonize </dev/null >/dev/null 2>&1
        ;;
    stop)
        qs kill -p "$UTIL" </dev/null >/dev/null 2>&1
        ;;
    restart)
        "$0" stop
        "$0" start
        ;;
    *)
        echo "usage: shells.sh start|stop|restart" >&2
        exit 2
        ;;
esac
exit 0
