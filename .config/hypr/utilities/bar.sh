#!/bin/bash
set -uo pipefail

HYPR="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
UTIL="$HYPR/utilities"
FILE="$HYPR/.active-bar"

current() {
    [ "$(cat "$FILE" 2>/dev/null)" = quickshell ] && echo quickshell || echo waybar
}

# Not recorded when the panel re-applies an entry, or records the pick itself.
record() {
    [ -n "${HYPR_SETTINGS_NO_RECORD:-}" ] || python3 "$UTIL/hypr-settings.py" set "$1" >/dev/null 2>&1 || true
}

start() {
    pkill -x waybar 2>/dev/null || true
    [ "$(current)" = waybar ] && setsid -f waybar >/dev/null 2>&1 </dev/null
    # The quickshell bar lives in the shared process; poke it in case the file watch missed the write.
    "$UTIL/shells.sh" bar refresh
}

case "${1:-}" in
    current)
        current
        ;;
    start)
        start
        ;;
    apply)
        kind="${2:?waybar|quickshell}"
        case "$kind" in
            waybar | quickshell) ;;
            *) echo "Unknown bar '$kind'" >&2; exit 1 ;;
        esac
        # Written whole and renamed into place, so the bar never reads a half-written file.
        printf '%s\n' "$kind" > "$FILE.tmp" && mv -f "$FILE.tmp" "$FILE"
        start
        record "bar.kind=\"$kind\""
        # Waybar goes back to its default config and style while it isn't the bar (recorded with the pick).
        if [ "$kind" = quickshell ]; then "$UTIL/waybar-style.sh" apply default; fi
        ;;
    style)
        name="${2:?name}"
        style="$(cut -d/ -f1 "$HYPR/.active-profile" 2>/dev/null || true)"
        [ -f "$HYPR/$style/quickshell/$name/config.json" ] || { echo "No quickshell bar style '$name' for $style" >&2; exit 1; }
        # Only the name: the bar reads the style's own config.json, so edits to it show at once.
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
        echo "usage: bar.sh start | apply waybar|quickshell | style <name> | toggle | current | <call> [args...]" >&2
        exit 2
        ;;
    *)
        "$UTIL/shells.sh" bar "$@"
        ;;
esac
