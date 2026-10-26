#!/bin/bash
set -uo pipefail

UTIL="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

call() {
    qs -p "$UTIL" ipc call "$@" >/dev/null 2>&1
}

# start the shared process if it isn't running, locked so two calls can't race
launch() (
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/quickshell-utilities.lock"
    flock -w 5 9 || exit 1
    qs ipc -p "$UTIL" show 2>/dev/null | grep -q '^target' && exit 0
    "$UTIL/hypr-profile.sh" links >/dev/null 2>&1 || true
    # 9>&- so the daemon doesn't keep the lock
    qs -n -p "$UTIL" --daemonize </dev/null >/dev/null 2>&1 9>&-
    for _ in $(seq 1 60); do
        qs ipc -p "$UTIL" show 2>/dev/null | grep -q '^target' && exit 0
        sleep 0.05
    done
    exit 1
)

# monitor under the cursor, in layout coords
cursor_monitor() {
    python3 -c '
import json, subprocess
run = lambda *a: json.loads(subprocess.run(["hyprctl", "-j", *a], capture_output=True, text=True).stdout)
pos = run("cursorpos")
for m in run("monitors"):
    w, h = (m["height"], m["width"]) if m["transform"] % 2 else (m["width"], m["height"])
    if m["x"] <= pos["x"] < m["x"] + w / m["scale"] and m["y"] <= pos["y"] < m["y"] + h / m["scale"]:
        print(m["name"])
        break
' 2>/dev/null
}

case "${1:-}" in
    start)
        launch
        exit 0
        ;;
    stop)
        qs kill -p "$UTIL" </dev/null >/dev/null 2>&1
        # kill returns before the process is gone
        for _ in $(seq 1 40); do
            qs list -p "$UTIL" 2>/dev/null | grep -q '^Instance' || break
            sleep 0.05
        done
        exit 0
        ;;
    restart)
        "$0" stop
        "$0" start
        exit 0
        ;;
    "")
        echo "usage: shells.sh start|stop|restart | <utility> [call [args...]]" >&2
        exit 2
        ;;
esac

target="$1"
shift
[ $# -gt 0 ] || set -- toggle

if [ "$target" = settings ] && { [ "$1" = toggle ] || [ "$1" = open ]; }; then
    set -- "$1On" "$(cursor_monitor)"
fi

call "$target" "$@" && exit 0
[ "$1" = close ] && exit 0

case "$1" in
    toggle) set -- open "${@:2}" ;;
    toggleOn) set -- openOn "${@:2}" ;;
esac
launch || exit 1
for _ in $(seq 1 20); do
    call "$target" "$@" && exit 0
    sleep 0.05
done
exit 1
