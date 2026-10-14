#!/usr/bin/env bash
# Re-runs install.sh with the current Pywal palette. Exits 75 if already running; output goes to the log.
set -uo pipefail

DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LOG="${XDG_RUNTIME_DIR:-/tmp}/boot-theme-install.log"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/boot-theme-install.lock"

exec 9>"$LOCK"
flock -n 9 || exit 75

if sudo -n true 2>/dev/null; then
    sudo -n "$DIR/install.sh" >"$LOG" 2>&1
elif pgrep -f -i "polkit.*agent|polkit-gnome-authentication|hyprpolkitagent|polkit-kde-authentication" >/dev/null; then
    pkexec "$DIR/install.sh" >"$LOG" 2>&1
else
    # No polkit agent to ask for the password, so fall back to a terminal prompt.
    kitty --title "Boot screen install" bash -c "sudo '$DIR/install.sh' 2>&1 | tee '$LOG'; exit \${PIPESTATUS[0]}"
fi
exit $?
