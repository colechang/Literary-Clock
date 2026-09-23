#!/bin/sh
# Paths are overridable so the loop can be exercised off-device:
#   LITCLOCK_FBINK=tools/fbink-stub LITCLOCK_CSV=quotes.csv ./litclock.sh
FBINK="${LITCLOCK_FBINK:-/mnt/sd/koreader/fbink}"
CSV="${LITCLOCK_CSV:-/mnt/sd/quotes.csv}"
FONT_DIR="${LITCLOCK_FONTS:-/mnt/sd/koreader/fonts/noto}"
REGULAR="$FONT_DIR/NotoSerif-Regular.ttf"
BOLD="$FONT_DIR/NotoSerif-Bold.ttf"
ITALIC="$FONT_DIR/NotoSerif-Italic.ttf"
BOLDITALIC="$FONT_DIR/NotoSerif-BoldItalic.ttf"
WEATHER_CACHE="/tmp/weather_cache.txt"
REFRESH_FLAG="/tmp/litclock_refresh"
CITY="Toronto"
WEATHER_FORMAT="%l:+%C,+%t"

# Refetch the weather once an hour; drop it from the screen if it goes stale.
WEATHER_TTL=10800          # 3h, in seconds
# Full flashing refresh this often, to clear eInk ghosting.
FLASH_INTERVAL=5           # minutes

# Re-sync the clock this often. litclock-start.sh syncs once at boot and
# nothing touched it again, but this device stays up for weeks and the i.MX RTC
# drifts — and a clock that quietly wanders off the correct time has failed at
# the only job it has.
NTP_SERVER="pool.ntp.org"

LAST_SYNC_DAY=$(date +%Y%m%d)   # boot sync just happened, so start from today
WEATHER_HOUR=""            # YYYYMMDDHH of the last successful fetch
WEATHER_AT=0               # epoch of the last successful fetch
LAST_FLASH=0               # epoch minute of the last flashing refresh
LAST_LINE=""               # so a tap does not redraw the same quote
ITER=0

while true; do
    # Keep nickel dead
    if [ -z "$LITCLOCK_FBINK" ]; then
        killall nickel 2>/dev/null
        killall fmon 2>/dev/null
    fi

    NOW=$(date +%s)
    TIME=$(date +%H:%M)
    ITER=$(expr $ITER + 1)

    # Re-sync the time once a day. Backgrounded so a slow or wedged ntpd can
    # never stall the render loop; the next attempt is a day out regardless of
    # how this one goes.
    TODAY=$(date +%Y%m%d)
    if [ "$TODAY" != "$LAST_SYNC_DAY" ]; then
        LAST_SYNC_DAY="$TODAY"
        (
            if ping -c 1 -W 2 "$NTP_SERVER" > /dev/null 2>&1; then
                BEFORE=$(date +%s)
                ntpd -nqp "$NTP_SERVER" 2>/dev/null
                AFTER=$(date +%s)
                # Includes however long ntpd took, so treat it as an upper
                # bound on the drift rather than an exact figure.
                echo "$(date '+%Y-%m-%d %H:%M:%S') time re-synced, clock moved $(expr $AFTER - $BEFORE)s (incl. sync time)" >> /tmp/litclock.log
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') time re-sync skipped, $NTP_SERVER unreachable" >> /tmp/litclock.log
            fi
        ) &
    fi

    # Fetch the weather at most once per wall-clock hour. Previously this was
    # gated on a counter that reset every 5 iterations, so it actually refetched
    # every 5 minutes.
    THIS_HOUR=$(date +%Y%m%d%H)
    if [ "$THIS_HOUR" != "$WEATHER_HOUR" ]; then
        FRESH=$(wget -q -T 5 -O - "wttr.in/$CITY?format=$WEATHER_FORMAT" 2>/dev/null)
        case "$FRESH" in
            ""|*Unknown*|*"<"*)
                : ;;   # offline, or wttr.in returned an error page
            *)
                # Capitalize and clean up
                echo "$FRESH" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2)); print}' > "$WEATHER_CACHE"
                WEATHER_HOUR="$THIS_HOUR"
                WEATHER_AT="$NOW"
                ;;
        esac
    fi

    # Show the cached reading while it is still recent. Previously this pinged
    # wttr.in every single minute, which kept the radio busy and blanked the
    # weather whenever a single ICMP probe was dropped.
    if [ "$WEATHER_AT" -gt 0 ] && [ $(expr $NOW - $WEATHER_AT) -lt $WEATHER_TTL ]; then
        WEATHER=$(cat "$WEATHER_CACHE" 2>/dev/null || echo "")
    else
        WEATHER=""
    fi

    # Pick exactly ONE random matching line, preferring one we did not just show.
    # Mixing the iteration count into the seed arithmetically (rather than
    # concatenating it, which overruns awk's integer precision) keeps successive
    # taps inside the same second from replaying the same sequence.
    SEED=$(expr $NOW + $ITER \* 7919)
    LINE=$(grep "^$TIME|" "$CSV" | awk -v seed="$SEED" -v last="$LAST_LINE" '
        BEGIN { srand(seed) }
        { lines[++n] = $0; if ($0 != last) pool[++m] = $0 }
        END {
            if (m > 0)      print pool[int(rand() * m) + 1]
            else if (n > 0) print lines[int(rand() * n) + 1]
        }')

    if [ -z "$LINE" ]; then
        QUOTE_TEXT="Time passes. ***$TIME***"
        ATTRIB=""
        DISPLAY_TEXT="$QUOTE_TEXT"
    else
        LAST_LINE="$LINE"
        QUOTE=$(echo "$LINE" | cut -d'|' -f3)
        HIGHLIGHT=$(echo "$LINE" | cut -d'|' -f2)
        BOOK=$(echo "$LINE" | cut -d'|' -f4 | sed 's/^ *//;s/ *$//')
        AUTHOR=$(echo "$LINE" | cut -d'|' -f5 | sed 's/^ *//;s/ *$//')
        # Escape only the characters that are special in a POSIX BRE. The old
        # set also escaped ( ) + ? { } |, which *turns them into* metacharacters
        # and silently loses the highlight (or aborts sed) on phrases like
        # "four (4) o'clock".
        ESCAPED=$(printf '%s' "$HIGHLIGHT" | sed 's/[][\.*^$]/\\&/g')
        # & and \ are special on the replacement side.
        REPLACE=$(printf '%s' "$HIGHLIGHT" | sed 's/[\&]/\\&/g')
        QUOTE_TEXT=$(echo "$QUOTE" | sed "s|$ESCAPED|***$REPLACE***|")
        ATTRIB="— $BOOK, $AUTHOR"
        DISPLAY_TEXT="$QUOTE_TEXT
$ATTRIB"
    fi

    # Full flash refresh every FLASH_INTERVAL minutes to prevent ghosting.
    # Keyed to the clock rather than to loop iterations, so tapping the screen
    # no longer drags the flash forward.
    THIS_MIN=$(expr $NOW / 60)
    if [ $(expr $THIS_MIN - $LAST_FLASH) -ge $FLASH_INTERVAL ]; then
        $FBINK -q -f -k
        LAST_FLASH=$THIS_MIN
        sleep 1
    fi

    # Adjust font size based on how much text actually gets drawn.
    #
    # Counted in characters, not bytes. The dataset is full of typographic
    # quotes and em-dashes, which are 3 bytes each in UTF-8, so `wc -c` charged
    # a quote for its punctuation and shrank the font: the old size-22 bucket
    # spanned 189-397 characters while size-26 spanned 54-248, so two quotes of
    # the same visible length could land in different buckets purely on how many
    # curly quotes they contained.
    #
    # Dropping the UTF-8 continuation bytes (0x80-0xBF) leaves exactly one byte
    # per character. LC_ALL=C is what makes tr byte-oriented rather than
    # character-oriented; without it this is a no-op in a UTF-8 locale. The ***
    # markers are fbink format markup and are never drawn, so they come off too.
    # Pick the largest font whose line budget fits.
    #
    # Counting characters is not enough. The quote and the attribution wrap as
    # two separate blocks — there is a hard line break between them — and each
    # block wastes part of its last line. Two blocks therefore take more lines
    # than one paragraph of the same length, and a character budget cannot see
    # that. A real 175-character quote overflowed at size 26 while a
    # 175-character lorem paragraph fitted; replacing only the newline with a
    # space made the identical text fit. (The bold markup is not the cause:
    # rendering with and without it overflowed by exactly the same amount.)
    #
    # fbink clips at the bottom margin rather than overflowing, so getting this
    # wrong silently truncates the quote mid-sentence and still looks fine.
    #
    # Both numbers below were measured on the panel, for this 800x600 area with
    # top=80/bottom=60: lines each size fits, and characters per line.
    #
    #   size  lines  chars/line
    #     26      7          27
    #     22      9          32
    #     18     11          41
    #     16     12          49
    #     14     14          60
    QLEN=$(printf '%s' "$QUOTE_TEXT" | sed 's/\*\*\*//g' | LC_ALL=C tr -d '\200-\277' | wc -c)
    ALEN=$(printf '%s' "$ATTRIB"     | sed 's/\*\*\*//g' | LC_ALL=C tr -d '\200-\277' | wc -c)

    FONT_SIZE=14
    for CAND in "26 27 7" "22 32 9" "18 41 11" "16 49 12" "14 60 14"; do
        set -- $CAND
        # Round each block up to whole lines independently.
        if [ $(( (QLEN + $2 - 1) / $2 + (ALEN + $2 - 1) / $2 )) -le $3 ]; then
            FONT_SIZE=$1
            break
        fi
    done

    # Night mode between 10pm and 6am
    HOUR=$(date +%H)
    if [ "$HOUR" -ge 22 ] || [ "$HOUR" -lt 6 ]; then
        NIGHT="-H"
    else
        NIGHT=""
    fi

    $FBINK -q -c -m -M $NIGHT -t regular="$REGULAR",bold="$BOLD",italic="$ITALIC",bolditalic="$BOLDITALIC",size=$FONT_SIZE,top=80,bottom=60,left=60,right=60,padding=BOTH,format "$DISPLAY_TEXT"

    [ -n "$WEATHER" ] && $FBINK -q -m $NIGHT -t regular="$REGULAR",size=14,top=15,bottom=520,left=60,right=60,padding=BOTH "$WEATHER"

    # Check every second for touch refresh signal
    SECS=$(date +%S)
    WAIT=$(expr 60 - $SECS)
    i=0
    while [ $i -lt $WAIT ]; do
        if [ -e "$REFRESH_FLAG" ]; then
            rm -f "$REFRESH_FLAG"
            break
        fi
        sleep 1
        i=$(expr $i + 1)
    done
done
