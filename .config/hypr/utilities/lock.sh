#!/bin/bash
# usage: lock.sh [--preview]
set -uo pipefail

UTIL="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
SHOTS="${XDG_RUNTIME_DIR:-/tmp}/quickshell-lock"

[ -e "$UTIL/lock/shell.qml" ] || "$UTIL/hypr-profile.sh" links >/dev/null 2>&1 || true

if [ "${1:-}" = --preview ]; then
    LOCK_PREVIEW=1 qs -p "$UTIL/lock" </dev/null >/dev/null 2>&1
    exit 0
fi

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/quickshell-lock.lock"
flock -n 9 || exit 0
qs -p "$UTIL/lock" </dev/null >/dev/null 2>&1
rm -rf "$SHOTS"
