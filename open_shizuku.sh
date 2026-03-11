#!/data/data/com.termux/files/usr/bin/sh

RISH="/data/data/com.termux/files/home/rish"

shizuku_running() {
    local test
    # We use a short timeout so the poll doesn't hang
    test=$($RISH -c "echo ping" 2>/dev/null)
    if [ "$test" = "ping" ]; then
        return 0
    fi
    return 1
}

termux-wifi-enable true

(
    count=0
    # Poll for Shizuku
    while ! shizuku_running; do
        if [ $count -gt 40 ]; then break; fi # ~20 second safety timeout
        sleep 0.2
        count=$((count + 1))
    done

    # Shizuku is ready!
    termux-wifi-enable false

    # Use the absolute system path to the input binary
    for i in 1 2; do
        $RISH -c "input keyevent 4"
    done
) &

#./off_wifi.sh &

exec /data/data/com.termux/files/usr/bin/am start \
--user 0 \
-n moe.shizuku.privileged.api/moe.shizuku.manager.MainActivity

