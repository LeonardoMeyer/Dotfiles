#!/bin/bash
set -uo pipefail

# Starts or stops every quickshell the active style ships as utilities/<name>/shell.qml.
# boot is excluded: it only runs once, launched by startup.lua with its own environment.
UTIL="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

shells() {
    local d
    for d in "$UTIL"/*/; do
        d="${d%/}"
        [ -f "$d/shell.qml" ] && [ "${d##*/}" != boot ] && printf '%s\n' "$d"
    done
}

case "${1:-}" in
    start)
        while IFS= read -r d; do
            qs -n -p "$d" --daemonize </dev/null >/dev/null 2>&1
        done < <(shells)
        ;;
    stop)
        while IFS= read -r d; do
            qs kill -p "$d" </dev/null >/dev/null 2>&1
        done < <(shells)
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
