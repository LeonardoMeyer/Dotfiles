#!/bin/bash
set -uo pipefail

HYPR="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
UTIL="$HYPR/utilities"
FILE="$HYPR/.active-bar"

current() {
    [ "$(cat "$FILE" 2>/dev/null)" = quickshell ] && echo quickshell || echo waybar
}

record() {
    [ -n "${HYPR_SETTINGS_NO_RECORD:-}" ] || python3 "$UTIL/hypr-settings.py" set "$1" >/dev/null 2>&1 || true
}

start() {
    pkill -x waybar 2>/dev/null || true
    [ "$(current)" = waybar ] && setsid -f waybar >/dev/null 2>&1 </dev/null
    "$UTIL/shells.sh" bar refresh
}

case "${1:-}" in
    current)
        current
        ;;
    start)
        start
        ;;
    boot)
        # profile decides the bar at login
        python3 "$UTIL/hypr-settings.py" sync >/dev/null 2>&1 || true
        start
        ;;
    apply)
        kind="${2:?waybar|quickshell}"
        case "$kind" in
            waybar | quickshell) ;;
            *) echo "Unknown bar '$kind'" >&2; exit 1 ;;
        esac
        # write then rename so it's never half written
        printf '%s\n' "$kind" > "$FILE.tmp" && mv -f "$FILE.tmp" "$FILE"
        start
        record "bar.kind=\"$kind\""
        if [ "$kind" = quickshell ]; then "$UTIL/waybar-style.sh" apply default; fi
        ;;
    style)
        name="${2:?name}"
        style="$(cut -d/ -f1 "$HYPR/.active-profile" 2>/dev/null || true)"
        [ -f "$HYPR/$style/quickshellbar/$name/config.json" ] || { echo "No quickshell bar style '$name' for $style" >&2; exit 1; }
        printf '%s\n' "$name" > "$HYPR/.quickshell-bar.tmp" && mv -f "$HYPR/.quickshell-bar.tmp" "$HYPR/.quickshell-bar"
        record "quickshell.style=\"$name\""
        ;;
    toggle)
        if [ "$(current)" = waybar ]; then
            if pgrep -x waybar >/dev/null; then pkill -x waybar; else setsid -f waybar >/dev/null 2>&1 </dev/null; fi
        else
            "$UTIL/shells.sh" bar toggle
        fi
        ;;
    "")
        echo "usage: bar.sh start | boot | apply waybar|quickshell | style <name> | toggle | current | <call> [args...]" >&2
        exit 2
        ;;
    *)
        "$UTIL/shells.sh" bar "$@"
        ;;
esac
