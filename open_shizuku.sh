#!/data/data/com.termux/files/usr/bin/sh

termux-wifi-enable true

(
  sleep 10
  termux-wifi-enable false
) &
#./off_wifi.sh &

exec /data/data/com.termux/files/usr/bin/am start \
--user 0 \
-n moe.shizuku.privileged.api/moe.shizuku.manager.MainActivity

