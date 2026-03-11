#!/data/data/com.termux/files/usr/bin/sh

RISH="/data/data/com.termux/files/home/rish"
SHIZUKU_PKG="moe.shizuku.privileged.api"

# Function to get current foreground app
get_fg_app() {
    $RISH -c "dumpsys activity activities" | grep "mFocusedApp" | sed -n 's/.*u0 \([^/]*\)\/.*/\1/p'
}

# 1. Turn on Wifi to trigger Shizuku
termux-wifi-enable true

# 2. Launch Shizuku
/data/data/com.termux/files/usr/bin/am start \
--user 0 \
-n moe.shizuku.privileged.api/moe.shizuku.manager.MainActivity > /dev/null 2>&1

# 3. Wait for Shizuku to actually take focus
while [ "$(get_fg_app)" != "$SHIZUKU_PKG" ]; do
    echo "retrying..."
done

# 4. Instant double-backspace then spam until gone
first_run=true
while [ "$(get_fg_app)" = "$SHIZUKU_PKG" ]; do
    if [ "$first_run" = true ]; then
        # Fire twice immediately on the first detection
        $RISH -c "input keyevent 4 && input keyevent 4"
        first_run=false
    else
        $RISH -c "input keyevent 4"
    fi
done

# 5. Clean up
termux-wifi-enable false
echo "Shizuku dismissed and WiFi disabled."

