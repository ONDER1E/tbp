#!/data/data/com.termux/files/usr/bin/bash

# Log for debugging
exec > /data/data/com.termux/files/home/tbp/control.log 2>&1
echo "Control helper started at $(date)"

STATE_FILE="/data/data/com.termux/files/home/tbp/monitor.state"

# Show menu dialog - corrected syntax for termux-dialog radio
RESPONSE=$(termux-dialog radio -t "USB PD Bypass Monitor" -v "Pause Monitor,Resume Monitor,Exit Monitor")
echo "Response: $RESPONSE"

if [[ "$RESPONSE" == *"Pause Monitor"* ]]; then
    echo "User chose to pause"
    echo "PAUSED" > "$STATE_FILE"
    termux-notification \
        --id 7421 \
        --title "USB PD Bypass Monitor" \
        --content "Monitor paused - tap to resume" \
        --action "bash -c '/data/data/com.termux/files/home/tbp/control.sh'" \
        --ongoing

elif [[ "$RESPONSE" == *"Resume Monitor"* ]]; then
    echo "User chose to resume"
    echo "RUNNING" > "$STATE_FILE"
    # Force a check immediately by sending signal to main process
    if [ -f /data/data/com.termux/files/home/tbp/monitor.pid ]; then
        PID=$(cat /data/data/com.termux/files/home/tbp/monitor.pid)
        kill -SIGUSR1 "$PID" 2>/dev/null
    fi

elif [[ "$RESPONSE" == *"Exit Monitor"* ]]; then
    echo "User chose to exit"

    # Find the monitor PID and kill it
    if [ -f /data/data/com.termux/files/home/tbp/monitor.pid ]; then
        PID=$(cat /data/data/com.termux/files/home/tbp/monitor.pid)
        echo "Found PID: $PID"

        # Kill the process and its children
        pkill -P "$PID" 2>/dev/null
        kill "$PID" 2>/dev/null
        sleep 1

        # Remove notification and files
        termux-notification-remove 7421
        rm -f /data/data/com.termux/files/home/tbp/monitor.pid
        rm -f "$STATE_FILE"

        echo "Monitor terminated"
    else
        echo "PID file not found"
    fi
fi