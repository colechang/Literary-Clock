#!/bin/sh
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/lib
export PATH

FBINK="/mnt/sd/koreader/fbink"
FONT_DIR="/mnt/sd/koreader/fonts/noto"
REGULAR="$FONT_DIR/NotoSerif-Regular.ttf"
ITALIC="$FONT_DIR/NotoSerif-Italic.ttf"

# Wait for SD card to be mounted
i=0
while [ $i -lt 30 ]; do
    mount | grep -q "mmcblk1p1" && break
    sleep 1
    i=$(expr $i + 1)
done

# Wait for nickel to fully start then kill it
sleep 15
killall nickel 2>/dev/null
killall sickel 2>/dev/null
killall sickel-launcher 2>/dev/null
killall touch_watcher.sh 2>/dev/null
killall litclock.sh 2>/dev/null
mount -o remount,rw /mnt/sd

# Sync time only if WiFi is up
if ping -c 1 -W 2 pool.ntp.org > /dev/null 2>&1; then
    ntpd -nqp pool.ntp.org 2>/dev/null
    echo "Time synced at $(date)" >> /tmp/litclock.log
fi

# Set landscape rotation
echo 2 > /sys/class/graphics/fb0/rotate

# Startup splash
$FBINK -q -c -m -M -t regular="$REGULAR",italic="$ITALIC",size=28,top=200,bottom=200,padding=BOTH,format "*Literary Clock*"
sleep 1
$FBINK -q -m -M -t regular="$REGULAR",italic="$ITALIC",size=14,top=320,bottom=250,padding=BOTH,format "time told in literature"
sleep 3

# Hand off to main clock loop
setsid nohup /mnt/sd/touch_watcher.sh 2> /tmp/touch_watcher.log &
setsid nohup /mnt/sd/litclock.sh 2> /tmp/litclock.log &
