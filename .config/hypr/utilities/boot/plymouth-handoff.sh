#!/bin/sh
# Runs in place of `plymouth quit` (plymouth-quit.service). Completes the bar,
# then keeps the final frame until greetd/Hyprland draws over it.
plymouth --ping 2>/dev/null || exit 0

timeout 3 systemctl stop plymouth-logfeed.service 2>/dev/null || true
plymouth display-message --text="@100" 2>/dev/null
sleep 0.2
plymouth quit --retain-splash 2>/dev/null
exit 0
