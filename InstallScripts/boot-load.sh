#!/bin/bash
# Run this file; do not `source` it. The work happens in a child shell, so a
# failure can never close your terminal, and the window waits for Enter at the end.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash -c 'source "$1/fullinstall.sh"; boot_screen' _ "$SCRIPT_DIR"
status=$?

echo
if [[ $status -eq 0 ]]; then
    echo "[✓] Finished."
else
    echo "[✗] Failed with exit code $status. Scroll up for the error."
fi
read -rp "Press Enter to close..." _ || true
exit "$status"
