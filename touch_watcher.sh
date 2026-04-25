#!/bin/sh
killall evtest 2>/dev/null
evtest /dev/input/event1 | while read LINE; do
    case "$LINE" in
        *"p: 0"*)
            # ignore lift events
            ;;
        *"Report Sync"*"p: "*)
            touch /tmp/litclock_refresh
            sleep 2
            ;;
    esac
done
