#!/data/data/com.termux/files/usr/bin/bash
# Show a confirmation dialog
RESPONSE=$(termux-dialog confirm -t "Stop Monitor?" -i "Do you want to stop the USB PD Bypass script?")

if [[ "$RESPONSE" == *"true"* ]]; then
    # Find the monitor PID and kill it
    PID=$(cat ~/tbp/monitor.pid)
    kill "$PID"
    termux-notification-remove 7421
fi