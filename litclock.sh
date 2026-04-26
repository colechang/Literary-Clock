#!/bin/sh
FBINK="/mnt/sd/koreader/fbink"
CSV="/mnt/sd/quotes.csv"
FONT_DIR="/mnt/sd/koreader/fonts/noto"
REGULAR="$FONT_DIR/NotoSerif-Regular.ttf"
BOLD="$FONT_DIR/NotoSerif-Bold.ttf"
ITALIC="$FONT_DIR/NotoSerif-Italic.ttf"
BOLDITALIC="$FONT_DIR/NotoSerif-BoldItalic.ttf"
COUNTER=0

while true; do
    # Keep nickel dead
    killall nickel 2>/dev/null
    killall fmon 2>/dev/null

    TIME=$(date +%H:%M)

    # Pick exactly ONE random matching line
    LINE=$(grep "^$TIME|" "$CSV" | awk 'BEGIN{srand()} {lines[NR]=$0} END{if(NR>0) print lines[int(rand()*NR)+1]}')

    if [ -z "$LINE" ]; then

        DISPLAY_TEXT="Time passes. ***$TIME***"
    else
        QUOTE=$(echo "$LINE" | cut -d'|' -f3)
        HIGHLIGHT=$(echo "$LINE" | cut -d'|' -f2)
        BOOK=$(echo "$LINE" | cut -d'|' -f4 | sed 's/^ *//;s/ *$//')
        AUTHOR=$(echo "$LINE" | cut -d'|' -f5 | sed 's/^ *//;s/ *$//')
        DISPLAY_TEXT=$(echo "$QUOTE" | sed "s|$HIGHLIGHT|***$HIGHLIGHT***|")
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
        FONT_SIZE=13
    elif [ "$QUOTE_LEN" -gt 250 ]; then
        FONT_SIZE=15
    else
        FONT_SIZE=18
    fi

    # Night mode between 10pm and 6am
    HOUR=$(date +%H)
    if [ "$HOUR" -ge 22 ] || [ "$HOUR" -lt 6 ]; then
        $FBINK -q -c -m -M -H -t regular="$REGULAR",bold="$BOLD",italic="$ITALIC",bolditalic="$BOLDITALIC",size=$FONT_SIZE,top=60,bottom=60,left=50,right=50,padding=BOTH,format "$DISPLAY_TEXT"
    else
        $FBINK -q -c -m -M -t regular="$REGULAR",bold="$BOLD",italic="$ITALIC",bolditalic="$BOLDITALIC",size=$FONT_SIZE,top=60,bottom=60,left=50,right=50,padding=BOTH,format "$DISPLAY_TEXT"
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

