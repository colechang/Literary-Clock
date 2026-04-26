#!/bin/sh
# Read raw touch events directly from input device
# Each input_event struct is 16 bytes on ARM 32-bit

while true; do
    # Read one event (16 bytes)
    dd if=/dev/input/event1 bs=16 count=1 2>/dev/null
    echo "Touch detected at $(date +%H:%M:%S)" >> /tmp/touch_watcher.log
    # Signal clock to refresh
    touch /tmp/litclock_refresh
    # Debounce - drain remaining events and wait
    dd if=/dev/input/event1 bs=16 count=100 iflag=nonblock 2>/dev/null
    sleep 2
done
