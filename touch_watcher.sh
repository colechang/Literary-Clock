#!/bin/sh
# Read raw touch events directly from input device
# Each input_event struct is 16 bytes on ARM 32-bit
# We just need to detect ANY touch activity

while true; do
    # Read one event (16 bytes)
    dd if=/dev/input/event1 bs=16 count=1 2>/dev/null
    # Any read means activity - create refresh flag
    touch /tmp/litclock_refresh
    # Debounce - drain remaining events and wait
    dd if=/dev/input/event1 bs=16 count=10 2>/dev/null
    sleep 2
done
