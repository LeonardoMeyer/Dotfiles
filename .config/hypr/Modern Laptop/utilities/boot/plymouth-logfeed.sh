#!/usr/bin/env bash
# Streams the live system log to the Plymouth splash, a few lines per second.
# Exits on its own once Plymouth stops answering (boot finished).
set -u

plymouth --ping 2>/dev/null || exit 0

re='^\[ *([0-9]+)\.([0-9]{3})[0-9]*\] ([^ :[]+)(\[[0-9]+\])?: (.*)$'
min_gap=150000 # microseconds between lines shown
last=0

exec 3< <(journalctl -b -f -n 3 --no-pager --no-hostname -o short-monotonic -p info 2>/dev/null)
jpid=$!
trap 'kill "$jpid" 2>/dev/null' EXIT

while IFS= read -r line <&3; do
  now=${EPOCHREALTIME/./}
  (( now - last < min_gap )) && continue
  [[ $line =~ $re ]] || continue
  printf -v msg '[%5s.%s] %s: %s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[5]}"
  plymouth display-message --text="$msg" 2>/dev/null || exit 0
  last=$now
done
