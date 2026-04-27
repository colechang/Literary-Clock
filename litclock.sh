#!/bin/sh
FBINK="/mnt/sd/koreader/fbink"
CSV="/mnt/sd/quotes.csv"
FONT_DIR="/mnt/sd/koreader/fonts/noto"
REGULAR="$FONT_DIR/NotoSerif-Regular.ttf"
BOLD="$FONT_DIR/NotoSerif-Bold.ttf"
ITALIC="$FONT_DIR/NotoSerif-Italic.ttf"
BOLDITALIC="$FONT_DIR/NotoSerif-BoldItalic.ttf"
WEATHER_CACHE="/tmp/weather_cache.txt"
CITY="Toronto"
WEATHER_FORMAT="%l:+%C,+%t"

COUNTER=0

while true; do
    # Keep nickel dead
    killall nickel 2>/dev/null
    killall fmon 2>/dev/null

    TIME=$(date +%H:%M)
    # Fetch weather every 60 minutes
    if [ $(expr $COUNTER % 60) -eq 0 ]; then
        # Check WiFi is up by pinging the router
        if ping -c 1 -W 2 wttr.in > /dev/null 2>&1; then
            FRESH=$(wget -q -T 5 -O - "wttr.in/$CITY?format=$WEATHER_FORMAT" 2>/dev/null)
            if [ -n "$FRESH" ]; then
                # Capitalize and clean up
                echo "$FRESH" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2)); print}' > "$WEATHER_CACHE"
            fi
        fi
    fi

    # Only show weather if cache exists and WiFi was available recently
    if ping -c 1 -W 1 wttr.in > /dev/null 2>&1; then
        WEATHER=$(cat "$WEATHER_CACHE" 2>/dev/null || echo "")
    else
        WEATHER=""
    fi

    # Pick exactly ONE random matching line
    LINE=$(grep "^$TIME|" "$CSV" | awk -v seed="$(date +%s%N)" 'BEGIN{srand(seed)} {lines[NR]=$0} END{if(NR>0) print lines[int(rand()*NR)+1]}')

    if [ -z "$LINE" ]; then

        DISPLAY_TEXT="Time passes. ***$TIME***"
    else
        QUOTE=$(echo "$LINE" | cut -d'|' -f3)
        HIGHLIGHT=$(echo "$LINE" | cut -d'|' -f2)
        BOOK=$(echo "$LINE" | cut -d'|' -f4 | sed 's/^ *//;s/ *$//')
        AUTHOR=$(echo "$LINE" | cut -d'|' -f5 | sed 's/^ *//;s/ *$//')
        ESCAPED=$(echo "$HIGHLIGHT" | sed 's/[.[\*^$()+?{}|]/\\&/g')
        DISPLAY_TEXT=$(echo "$QUOTE" | sed "s|$ESCAPED|***$HIGHLIGHT***|")
        DISPLAY_TEXT="$DISPLAY_TEXT
— $BOOK, $AUTHOR"
    fi

    # Full flash refresh every 5 minutes to prevent ghosting
    COUNTER=$(expr $COUNTER + 1)
    if [ $COUNTER -ge 5 ]; then
        $FBINK -q -f -k
        COUNTER=0
        sleep 1
    fi

    # Adjust font size based on quote length
    QUOTE_LEN=$(echo "$DISPLAY_TEXT" | wc -c)
    if [ "$QUOTE_LEN" -gt 400 ]; then
        FONT_SIZE=18
    elif [ "$QUOTE_LEN" -gt 250 ]; then
        FONT_SIZE=22
    else
        FONT_SIZE=26
    fi

    # Night mode between 10pm and 6am
    HOUR=$(date +%H)
    if [ "$HOUR" -ge 22 ] || [ "$HOUR" -lt 6 ]; then
        $FBINK -q -c -m -M -H -t regular="$REGULAR",bold="$BOLD",italic="$ITALIC",bolditalic="$BOLDITALIC",size=$FONT_SIZE,top=60,bottom=60,left=60,right=60,padding=BOTH,format "$DISPLAY_TEXT"
        [ -n "$WEATHER" ] && $FBINK -q -m -H -t regular="$REGULAR",size=14,top=15,bottom=520,left=60,right=60,padding=BOTH "$WEATHER"
    else
        $FBINK -q -c -m -M -t regular="$REGULAR",bold="$BOLD",italic="$ITALIC",bolditalic="$BOLDITALIC",size=$FONT_SIZE,top=60,bottom=60,left=60,right=60,padding=BOTH,format "$DISPLAY_TEXT"
        [ -n "$WEATHER" ] && $FBINK -q -m -t regular="$REGULAR",size=14,top=15,bottom=520,left=60,right=60,padding=BOTH "$WEATHER"
    fi

    # Check every second for touch refresh signal
    SECS=$(date +%S)
    WAIT=$(expr 60 - $SECS)
    i=0
    while [ $i -lt $WAIT ]; do
        if [ -e /tmp/litclock_refresh ]; then
            rm /tmp/litclock_refresh
            break
        fi
        sleep 1
        i=$(expr $i + 1)
    done
done

