#!/data/data/com.termux/files/usr/bin/sh

RISH="/data/data/com.termux/files/home/rish"
SHIZUKU_PKG="moe.shizuku.privileged.api"

# Function to get the current foreground app using your device's specific output
get_fg_app() {
    $RISH -c "dumpsys activity activities" | grep "mFocusedApp" | sed -n 's/.*u0 \([^/]*\)\/.*/\1/p'
}

# 1. Turn on Wifi to trigger Shizuku
termux-wifi-enable true

# 2. Launch Shizuku
/data/data/com.termux/files/usr/bin/am start \
--user 0 \
-n moe.shizuku.privileged.api/moe.shizuku.manager.MainActivity > /dev/null 2>&1

# 3. Wait for Shizuku to actually take focus before we start spamming
while [ "$(get_fg_app)" != "$SHIZUKU_PKG" ]; do
    echo "retying..."
done

# 4. Spam back button with no delay until Shizuku is no longer in focus
while [ "$(get_fg_app)" = "$SHIZUKU_PKG" ]; do
    $RISH -c "input keyevent 4"
done

# 5. Clean up
termux-wifi-enable false
echo "Shizuku dismissed and WiFi disabled."

