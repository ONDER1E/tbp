#!/data/data/com.termux/files/usr/bin/bash

########################################
# Configuration
########################################
RISH="/data/data/com.termux/files/home/rish"

ENABLE_THRESHOLD=42
DISABLE_THRESHOLD=38
INTERVAL=5
MIN_STATE_SECONDS=60
MAX_ATTEMPTS=10

LOCK_FILE="./monitor.pid"
LOG_FILE="./monitor.log"

# Notification
NOTIF_ID=7421
NOTIF_GROUP="tbp_status"

# Correct Shizuku launcher activity
SHIZUKU_ACTIVITY="moe.shizuku.privileged.api/moe.shizuku.manager.MainActivity"

########################################
# Singleton protection
########################################
if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "Another instance already running (PID $OLD_PID)"
        exit 1
    fi
fi

echo $$ > "$LOCK_FILE"

########################################
# Cleanup
########################################
cleanup() {
    echo "$(date '+%F %T') | Shutting down monitor." >> "$LOG_FILE"
    termux-notification-remove "$NOTIF_ID" 2>/dev/null
    rm -f "$LOCK_FILE"
    exit 0
}

trap cleanup INT TERM EXIT

########################################
# Shizuku check
########################################
shizuku_running() {

    local test

    test=$($RISH -c "echo ping" 2>/dev/null)

    if [ "$test" = "ping" ]; then
        return 0
    fi

    return 1
}
########################################
# Retry reader
########################################
retry_read() {

    local cmd="$1"
    local attempt=1
    local RAW TMP

    while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do

        RAW=$($RISH -c "$cmd" 2>/dev/null)
        TMP=$(echo "$RAW" | tr -cd '0-9')

        if [[ "$TMP" =~ ^[0-9]+$ ]]; then
            echo "$TMP"
            return 0
        fi

        attempt=$((attempt+1))
        sleep 1
    done

    return 1
}

########################################
# Notification updater
########################################
update_notification() {

    local battery="$1"
    local state="$2"
    local title mode

    if [ "$state" -eq 1 ]; then
        title="USB PD Bypass Active"
        mode="Bypass Mode"
    else
        title="USB PD Bypass Disabled"
        mode="Normal Mode"
    fi

    termux-notification \
        --id "$NOTIF_ID" \
        --title "$title" \
        --content "Battery ${battery}% (${mode})" \
        --ongoing \
        --group "$NOTIF_GROUP" \
        --action "bash -c 'if termux-dialog confirm -t \"Stop Monitor?\" -i \"Exit the bypass script?\"; then kill $BASHPID; fi'" \
        2>/dev/null
}

########################################
# Log start
########################################
echo "========================================" >> "$LOG_FILE"
echo "$(date '+%F %T') | Monitor started." >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

LAST_TOGGLE_TIME=0

########################################
# Main loop
########################################
while true; do

    TIMESTAMP=$(date '+%F %T')

    ########################################
    # SHIZUKU CHECK
    ########################################
    if ! shizuku_running; then

        echo "$TIMESTAMP | WARNING: Shizuku not running." >> "$LOG_FILE"

        termux-notification \
            --id "$NOTIF_ID" \
            --title "Bypass Monitor Paused" \
            --content "Tap to open Shizuku" \
            --ongoing \
            --action "/data/data/com.termux/files/usr/bin/sh ~/tbp/open_shizuku.sh" \
            2>/dev/null

        sleep "$INTERVAL"
        continue
    fi

    ########################################
    # READ BATTERY
    ########################################
    BATTERY=$(retry_read "dumpsys battery | grep -m 1 level: | awk '{print \$2}'")

    if [ $? -ne 0 ]; then
        echo "$TIMESTAMP | ERROR: Battery unreadable." >> "$LOG_FILE"
        sleep "$INTERVAL"
        continue
    fi

    ########################################
    # DETERMINE TARGET STATE
    ########################################
    if [ "$BATTERY" -ge "$ENABLE_THRESHOLD" ]; then
        DESIRED=1
    elif [ "$BATTERY" -le "$DISABLE_THRESHOLD" ]; then
        DESIRED=0
    else

        CURRENT_STATE=$(retry_read "settings get system pass_through")
        [ -z "$CURRENT_STATE" ] && CURRENT_STATE=0

        update_notification "$BATTERY" "$CURRENT_STATE"
        sleep "$INTERVAL"
        continue
    fi

    ########################################
    # COOLDOWN
    ########################################
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - LAST_TOGGLE_TIME))

    if [ "$ELAPSED" -lt "$MIN_STATE_SECONDS" ]; then
        update_notification "$BATTERY" "$DESIRED"
        sleep "$INTERVAL"
        continue
    fi

    ########################################
    # APPLY CHANGE
    ########################################
    CURRENT_STATE=$(retry_read "settings get system pass_through")

    if [ "$CURRENT_STATE" -ne "$DESIRED" ]; then

        echo "$TIMESTAMP | Changing pass_through $CURRENT_STATE -> $DESIRED" >> "$LOG_FILE"

        $RISH -c "settings put system pass_through $DESIRED" >/dev/null 2>&1

        LAST_TOGGLE_TIME=$CURRENT_TIME
    fi

    update_notification "$BATTERY" "$DESIRED"

    sleep "$INTERVAL"

done