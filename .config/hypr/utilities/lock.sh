#!/bin/bash
# usage: lock.sh [--preview]
set -uo pipefail

UTIL="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
SHOTS="${XDG_RUNTIME_DIR:-/tmp}/quickshell-lock"

[ -e "$UTIL/lock/shell.qml" ] || "$UTIL/hypr-profile.sh" links >/dev/null 2>&1 || true

# screenshot every monitor while qs starts up, the lock fades in from these
shoot() {
    rm -rf "$SHOTS" && mkdir -p "$SHOTS"
    (
        for o in $(hyprctl -j monitors | jq -r '.[].name'); do grim -t ppm -o "$o" "$SHOTS/$o.ppm" & done
        wait
        : >"$SHOTS/.done"
    ) 9>&- &
}

if [ "${1:-}" = --preview ]; then
    shoot
    LOCK_PREVIEW=1 qs -p "$UTIL/lock.qml" </dev/null >/dev/null 2>&1
    exit 0
fi

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/quickshell-lock.lock"
# already locked: give up. one still quitting after unlock: wait for it so super+l never gets eaten
flock -w 1 9 || exit 0
shoot
qs -p "$UTIL/lock.qml" </dev/null >/dev/null 2>&1
rm -rf "$SHOTS"
