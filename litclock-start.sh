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
mount -o remount,rw /mnt/sd

# Startup splash
$FBINK -c -m -M -t regular="$REGULAR",italic="$ITALIC",size=28,top=200,bottom=200,padding=BOTH,format "*Literary Clock*"
sleep 1
$FBINK -m -M -t regular="$REGULAR",italic="$ITALIC",size=14,top=320,bottom=250,padding=BOTH,format "time told in literature"
sleep 3

# Hand off to main clock loop
setsid nohup /mnt/sd/litclock.sh > /tmp/litclock.log 2>&1 &