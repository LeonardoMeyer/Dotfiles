#!/usr/bin/env bash
# Regenerates boot/preview.png from the current Pywal palette (no root needed).
set -euo pipefail
DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
i=0
while IFS= read -r color || [[ -n $color ]]; do
  [[ -z $color ]] && continue
  echo "color$i=$color"
  i=$((i + 1))
done < "$HOME/.cache/wal/colors" > "$tmp/palette.conf"
python3 "$DIR/generate-assets.py" "$tmp/palette.conf" "$tmp/assets" "$DIR/preview.png"
