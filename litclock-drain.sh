#!/bin/sh
# Keeps a reader attached to nickel's hardware-status FIFO.
#
# /tmp/nickel-hardware-status is a FIFO that nickel owns and reads. Every stock
# Kobo hardware-event handler ends by writing to it:
#
#   /usr/local/Kobo/ntpd.sh        echo ntp  > /tmp/nickel-hardware-status
#   /usr/local/Kobo/udev/bat       battery events
#   /usr/local/Kobo/udev/ac        charger events
#   /usr/local/Kobo/udev/plug      USB events
#   /usr/local/Kobo/udev/sd        SD card events
#   /usr/local/Kobo/udev/input     input events
#
# This project kills nickel, which leaves that FIFO with no reader — so every
# one of those writers blocks in open() forever instead of exiting. Nothing
# reports it: the clock keeps running while stuck processes pile up. Measured
# on a unit after 116 days of uptime: 226 stranded ntpd.sh, 12 stranded plug
# handlers, 297 processes total, ~30MB of RAM held.
#
# Attaching a reader lets them complete and exit normally, and also immediately
# releases everything already blocked.
FIFO=/tmp/nickel-hardware-status

while true; do
    if [ -p "$FIFO" ]; then
        # Blocks in open() without spinning until a writer shows up, then
        # returns at EOF once the last one closes. Reopen for the next event.
        cat "$FIFO" > /dev/null 2>&1
        sleep 1
    else
        # Not created yet (or not a FIFO) — check back periodically.
        sleep 30
    fi
done
