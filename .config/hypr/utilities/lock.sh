#!/bin/bash
# Locks the session with the quickshell lock (utilities/lock), which replaced hyprlock (archive/hyprlock/).
# Runs alone, not in the shared shells.sh process: a lock has to come up even when that one is down or busy.
#   lock.sh            lock now; does nothing if already locked (hypridle's lock_cmd and SUPER+l)
#   lock.sh --preview  show it in windows without locking, to try the gear menu's settings (Esc closes)
set -uo pipefail

UTIL="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
SHOTS="${XDG_RUNTIME_DIR:-/tmp}/quickshell-lock"

# The lock folder is a link into the active style; make sure it is there.
[ -e "$UTIL/lock/shell.qml" ] || "$UTIL/hypr-profile.sh" links >/dev/null 2>&1 || true

if [ "${1:-}" = --preview ]; then
    LOCK_PREVIEW=1 qs -p "$UTIL/lock" </dev/null >/dev/null 2>&1
    exit 0
fi

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/quickshell-lock.lock"
flock -n 9 || exit 0
qs -p "$UTIL/lock" </dev/null >/dev/null 2>&1
# The frames it faded from are of the unlocked desktop; don't leave them lying around.
rm -rf "$SHOTS"
