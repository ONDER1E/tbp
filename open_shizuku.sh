#!/data/data/com.termux/files/usr/bin/sh

RISH="/data/data/com.termux/files/home/rish"
SHIZUKU_PKG="moe.shizuku.privileged.api"

get_fg_app() {
    $RISH -c "dumpsys window | grep -E 'mCurrentFocus|mFocusedApp' | head -n 1" \
    | sed 's/.*u0 \([^/]*\)\/.*/\1/' | tr -d '[:space:]'
}

echo "Turning on WiFi..."
termux-wifi-enable true
sleep 1

echo "Launching Shizuku..."
/data/data/com.termux/files/usr/bin/am start \
  --user 0 -n moe.shizuku.privileged.api/moe.shizuku.manager.MainActivity >/dev/null 2>&1

echo "Waiting for Shizuku to appear..."
timeout=15
while [ $timeout -gt 0 ]; do
    if [ "$(get_fg_app)" = "$SHIZUKU_PKG" ]; then
        echo "Shizuku detected in foreground. Dismissing..."
        break
    fi
    sleep 0.4
    timeout=$((timeout - 1))
done

if [ $timeout -eq 0 ]; then
    echo "Timeout: Shizuku did not appear in foreground."
    termux-wifi-enable false
    exit 1
fi

# Dismiss with back key (double first, then single)
$RISH -c "input keyevent 4 && input keyevent 4"
sleep 0.3

while [ "$(get_fg_app)" = "$SHIZUKU_PKG" ]; do
    $RISH -c "input keyevent 4"
    sleep 0.25   # prevent over-spamming
done

termux-wifi-enable false
echo "Shizuku dismissed successfully."
