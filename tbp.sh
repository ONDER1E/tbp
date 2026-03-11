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
STATE_FILE="./monitor.state"

# Notification
NOTIF_ID=7421
NOTIF_GROUP="tbp_status"

# Correct Shizuku launcher activity
SHIZUKU_ACTIVITY="moe.shizuku.privileged.api/moe.shizuku.manager.MainActivity"

# Number of failed checks before showing "paused" notification
SHIZUKU_GRACE_CYCLES=3

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
    rm -f "$LOCK_FILE" "$STATE_FILE"
    exit 0
}

trap cleanup INT TERM EXIT

########################################
# Signal handler for force check (when resuming)
########################################
force_check() {
    echo "$(date '+%F %T') | Forced check by signal" >> "$LOG_FILE"
}
trap force_check SIGUSR1

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
# Notification helpers
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
        --action "bash -c '/data/data/com.termux/files/home/tbp/control.sh'" \
        2>/dev/null
}

update_paused_notification() {
    termux-notification \
        --id "$NOTIF_ID" \
        --title "Bypass Monitor Paused" \
        --content "Shizuku not responding – tap to open" \
        --ongoing \
        --group "$NOTIF_GROUP" \
        --action "/data/data/com.termux/files/usr/bin/sh /data/data/com.termux/files/home/tbp/open_shizuku.sh" \
        2>/dev/null
}

update_manually_paused_notification() {
    termux-notification \
        --id "$NOTIF_ID" \
        --title "USB PD Bypass Monitor" \
        --content "Monitor paused - tap to resume" \
        --ongoing \
        --group "$NOTIF_GROUP" \
        --action "bash -c '/data/data/com.termux/files/home/tbp/control.sh'" \
        2>/dev/null
}

########################################
# Log start
########################################
echo "========================================" >> "$LOG_FILE"
echo "$(date '+%F %T') | Monitor started." >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

LAST_TOGGLE_TIME=0
FAILED_SHIZUKU_COUNT=0
LAST_BATTERY=""
LAST_STATE=""
MANUAL_PAUSE=0

########################################
# Main loop
########################################
while true; do

    TIMESTAMP=$(date '+%F %T')

    # ─────────────────────────────────────────
    # Check for manual pause state
    # ─────────────────────────────────────────
    if [ -f "$STATE_FILE" ]; then
        STATE=$(cat "$STATE_FILE")
        if [ "$STATE" = "PAUSED" ]; then
            if [ $MANUAL_PAUSE -eq 0 ]; then
                MANUAL_PAUSE=1
                echo "$TIMESTAMP | Monitor manually paused" >> "$LOG_FILE"
                update_manually_paused_notification
            fi
            sleep "$INTERVAL"
            continue
        else
            if [ $MANUAL_PAUSE -eq 1 ]; then
                MANUAL_PAUSE=0
                echo "$TIMESTAMP | Monitor resumed" >> "$LOG_FILE"
            fi
        fi
    fi

    # ─────────────────────────────────────────
    # 1. Check Shizuku
    # ─────────────────────────────────────────
    if shizuku_running; then
        FAILED_SHIZUKU_COUNT=0
    else
        FAILED_SHIZUKU_COUNT=$((FAILED_SHIZUKU_COUNT + 1))
        echo "$TIMESTAMP | Shizuku check failed ($FAILED_SHIZUKU_COUNT/$SHIZUKU_GRACE_CYCLES)" >> "$LOG_FILE"
    fi

    # ─────────────────────────────────────────
    # 2. Try to read battery & state (if Shizuku appears alive)
    # ─────────────────────────────────────────
    if shizuku_running; then
        BATTERY=$(retry_read "dumpsys battery | grep -m 1 level: | awk '{print \$2}'")

        if [ $? -eq 0 ] && [ -n "$BATTERY" ]; then
            LAST_BATTERY="$BATTERY"

            CURRENT_STATE=$(retry_read "settings get system pass_through")
            [ -z "$CURRENT_STATE" ] && CURRENT_STATE=0
            LAST_STATE="$CURRENT_STATE"
        fi
    fi

    # ─────────────────────────────────────────
    # 3. Decide what notification to show
    # ─────────────────────────────────────────
    if [ "$FAILED_SHIZUKU_COUNT" -ge "$SHIZUKU_GRACE_CYCLES" ]; then
        # After grace period → show paused
        update_paused_notification
    elif [ -n "$LAST_BATTERY" ] && [ -n "$LAST_STATE" ]; then
        # During grace period or when working → show last known values
        update_notification "$LAST_BATTERY" "$LAST_STATE"
    fi

    # If we still don't have any data at all, just wait
    if [ -z "$LAST_BATTERY" ]; then
        sleep "$INTERVAL"
        continue
    fi

    # ─────────────────────────────────────────
    # 4. Control logic only runs when Shizuku is responding
    # ─────────────────────────────────────────
    if ! shizuku_running; then
        sleep "$INTERVAL"
        continue
    fi

    # Determine desired state
    if [ "$LAST_BATTERY" -ge "$ENABLE_THRESHOLD" ]; then
        DESIRED=1
    elif [ "$LAST_BATTERY" -le "$DISABLE_THRESHOLD" ]; then
        DESIRED=0
    else
        # In hysteresis zone → just keep current notification
        sleep "$INTERVAL"
        continue
    fi

    # Cooldown / min time between changes
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - LAST_TOGGLE_TIME))

    if [ "$ELAPSED" -lt "$MIN_STATE_SECONDS" ]; then
        sleep "$INTERVAL"
        continue
    fi

    # Apply change if needed
    CURRENT_STATE=$(retry_read "settings get system pass_through")

    if [ "$CURRENT_STATE" != "$DESIRED" ]; then
        echo "$TIMESTAMP | Changing pass_through $CURRENT_STATE -> $DESIRED" >> "$LOG_FILE"
        $RISH -c "settings put system pass_through $DESIRED" >/dev/null 2>&1
        LAST_TOGGLE_TIME=$CURRENT_TIME
    fi

    sleep "$INTERVAL"

done
