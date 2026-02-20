#!/data/data/com.termux/files/usr/bin/bash

RISH="/data/data/com.termux/files/home/rish"

ENABLE_THRESHOLD=42
DISABLE_THRESHOLD=38
INTERVAL=5
MIN_STATE_SECONDS=60
MAX_ATTEMPTS=10

VERBOSE_LOGGING=false

LOCK_FILE="./monitor.pid"
LOG_FILE="./monitor.log"

########################################
# Singleton protection
########################################
if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "Another instance is already running (PID $OLD_PID). Exiting."
        exit 1
    fi
fi
echo $$ > "$LOCK_FILE"

cleanup() {
    echo "$(date '+%F %T') | Shutting down monitor." >> "$LOG_FILE"
    rm -f "$LOCK_FILE"
    exit 0
}
trap cleanup INT TERM

########################################
# Startup log
########################################
echo "========================================" >> "$LOG_FILE"
echo "$(date '+%F %T') | Monitor started." >> "$LOG_FILE"
echo "Enable >= $ENABLE_THRESHOLD | Disable <= $DISABLE_THRESHOLD" >> "$LOG_FILE"
echo "Check interval: $INTERVAL seconds" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

LAST_TOGGLE_TIME=0

########################################
# Shizuku check
########################################
shizuku_running() {
    $RISH -c "echo ok" >/dev/null 2>&1
    return $?
}

########################################
# Generic 10‑attempt reader
########################################
retry_read() {
    local cmd="$1"
    local attempt=1
    local RAW TMP

    while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
        RAW=$($RISH -c "$cmd" 2>/dev/null)

        $VERBOSE_LOGGING && echo "$(date '+%F %T') | [VERBOSE] Attempt $attempt: Raw='$RAW'" >> "$LOG_FILE"

        TMP=$(echo "$RAW" | tr -cd '0-9')
        $VERBOSE_LOGGING && echo "$(date '+%F %T') | [VERBOSE] Attempt $attempt: Sanitized='$TMP'" >> "$LOG_FILE"

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
# Main loop
########################################
while true; do
    TIMESTAMP=$(date '+%F %T')

    if ! shizuku_running; then
        echo "$TIMESTAMP | WARNING: Shizuku not running. Skipping cycle." >> "$LOG_FILE"
        sleep "$INTERVAL"
        continue
    fi

    ########################################
    # Read battery (10 attempts)
    ########################################
    BATTERY=$(retry_read "dumpsys battery | grep -m 1 level: | awk '{print \$2}'")

    if [ $? -ne 0 ]; then
        echo "$TIMESTAMP | ERROR: Battery unreadable after $MAX_ATTEMPTS attempts." >> "$LOG_FILE"
        sleep "$INTERVAL"
        continue
    fi

    echo "$TIMESTAMP | Battery=${BATTERY}%" >> "$LOG_FILE"

    ########################################
    # Determine desired state
    ########################################
    if [ "$BATTERY" -ge "$ENABLE_THRESHOLD" ]; then
        DESIRED=1
    elif [ "$BATTERY" -le "$DISABLE_THRESHOLD" ]; then
        DESIRED=0
    else
        sleep "$INTERVAL"
        continue
    fi

    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - LAST_TOGGLE_TIME))

    if [ "$ELAPSED" -lt "$MIN_STATE_SECONDS" ]; then
        sleep "$INTERVAL"
        continue
    fi

    ########################################
    # Read current passthrough (10 attempts)
    ########################################
    CURRENT_STATE=$(retry_read "settings get system pass_through")

    if [ $? -ne 0 ]; then
        echo "$TIMESTAMP | WARNING: Could not read pass_through. Applying expected state=$DESIRED" >> "$LOG_FILE"
        $RISH -c "settings put system pass_through $DESIRED" >/dev/null 2>&1
        LAST_TOGGLE_TIME=$CURRENT_TIME
        sleep "$INTERVAL"
        continue
    fi

    ########################################
    # Only set if different
    ########################################
    if [ "$CURRENT_STATE" -ne "$DESIRED" ]; then
        echo "$TIMESTAMP | Changing pass_through $CURRENT_STATE → $DESIRED" >> "$LOG_FILE"
        $RISH -c "settings put system pass_through $DESIRED" >/dev/null 2>&1
        LAST_TOGGLE_TIME=$CURRENT_TIME
    else
        $VERBOSE_LOGGING && echo "$TIMESTAMP | [VERBOSE] pass_through already $CURRENT_STATE — no change" >> "$LOG_FILE"
    fi

    sleep "$INTERVAL"
done
