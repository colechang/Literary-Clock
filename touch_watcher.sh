#!/bin/sh
# Watch for touch events and signal litclock to refresh
# Uses dd to read raw input events - each event is 16 bytes on ARM
# We watch for EV_KEY (type 1) or EV_ABS (type 3) events
# Belongs on /mnt/sd

while true; do
    # Read raw input - dd reads one event at a time
    # On touch, create the refresh flag
    dd if=/dev/input/event0 bs=16 count=1 2>/dev/null | od -t x1 | grep -q "01 00\|03 00"
    if [ $? -eq 0 ]; then
        touch /tmp/litclock_refresh
        # Debounce - ignore further touches for 2 seconds
        sleep 2
    fi
done
EOF
