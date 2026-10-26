#!/bin/bash
set -uo pipefail

# usage: osd.sh vol-up|vol-down|vol-mute|mic-mute|bright-up|bright-down|caps|play|next|prev

DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

show() {
    "$DIR/shells.sh" osd notify "$@"
}

# prints "<volume> <muted>"
audio_state() {
    local out v
    out="$(wpctl get-volume "$1")" || return 1
    v="${out#Volume: }"
    v="${v%% *}"
    [[ "$out" == *MUTED* ]] && echo "$v true" || echo "$v false"
}

SINK=@DEFAULT_AUDIO_SINK@
SOURCE=@DEFAULT_AUDIO_SOURCE@

case "${1:-}" in
    vol-up | vol-down)
        wpctl set-mute "$SINK" 0
        wpctl set-volume -l 1.0 "$SINK" "5%$([[ $1 == vol-up ]] && echo + || echo -)"
        read -r v m < <(audio_state "$SINK") && show volume "$v" "$m" ""
        ;;
    vol-mute)
        wpctl set-mute "$SINK" toggle
        read -r v m < <(audio_state "$SINK") && show volume "$v" "$m" ""
        ;;
    mic-mute)
        wpctl set-mute "$SOURCE" toggle
        read -r v m < <(audio_state "$SOURCE") && show mic 0 "$m" ""
        ;;
    bright-up | bright-down)
        out="$(brightnessctl -m -n1 set "10%$([[ $1 == bright-up ]] && echo + || echo -)")" || exit 1
        pct="$(cut -d, -f4 <<<"$out" | tr -d '%')"
        show brightness "$(awk -v p="$pct" 'BEGIN { print p / 100 }')" false ""
        ;;
    caps)
        sleep 0.1
        on=false
        for f in /sys/class/leds/*capslock/brightness; do
            [[ -r "$f" && "$(<"$f")" != 0 ]] && on=true
        done
        show caps 0 "$on" ""
        ;;
    play | next | prev)
        case "$1" in
            play) playerctl play-pause ;;
            next) playerctl next ;;
            prev) playerctl previous ;;
        esac
        sleep 0.2
        info="$(playerctl metadata --format '{{status}}|{{title}}' 2>/dev/null)"
        status="${info%%|*}"
        title="${info#*|}"
        if [[ "$1" == play ]]; then
            [[ "$status" == Playing ]] && kind=play || kind=pause
        else
            kind="$1"
        fi
        show "$kind" 0 false "$title"
        ;;
    *)
        echo "unknown action: ${1:-}" >&2
        exit 2
        ;;
esac
