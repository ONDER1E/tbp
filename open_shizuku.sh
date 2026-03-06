#!/data/data/com.termux/files/usr/bin/sh

termux-wifi-enable true

exec /data/data/com.termux/files/usr/bin/am start \
--user 0 \
-n moe.shizuku.privileged.api/moe.shizuku.manager.MainActivity

sleep 30

termux-wifi-enable false