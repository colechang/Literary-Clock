#!/bin/sh
# Respawn supervisor. Runs its argument forever, restarting it if it exits,
# with a backoff so a program that dies immediately cannot spin the CPU.
#
#   litclock-run.sh /mnt/sd/litclock.sh
#
# Without this, a single fatal error in the clock loop leaves the eInk screen
# frozen on the last quote indefinitely — the failure is invisible, because a
# stopped eInk display looks exactly like a working one.
PROG="$1"
[ -n "$PROG" ] || { echo "usage: litclock-run.sh <program>" >&2; exit 2; }

NAME=$(basename "$PROG")
BACKOFF=1

while true; do
    START=$(date +%s)
    "$PROG"
    STATUS=$?
    RAN=$(expr $(date +%s) - $START)

    echo "$(date '+%Y-%m-%d %H:%M:%S') $NAME exited (status $STATUS) after ${RAN}s; restarting in ${BACKOFF}s" >> /tmp/litclock.log

    sleep $BACKOFF

    # Ran long enough to be healthy? Reset. Otherwise back off, capped at 60s.
    if [ "$RAN" -ge 60 ]; then
        BACKOFF=1
    elif [ "$BACKOFF" -lt 60 ]; then
        BACKOFF=$(expr $BACKOFF \* 2)
    fi
done
