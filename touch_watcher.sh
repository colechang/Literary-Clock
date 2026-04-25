#!/bin/sh
evtest /dev/input/event1 | while read LINE; do
    case "$LINE" in
        *BTN_TOUCH*value\ 1*)
            touch /tmp/litclock_refresh
            sleep 2
            ;;
    esac
done

