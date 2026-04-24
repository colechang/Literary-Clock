#!/bin/sh

FBINK="/mnt/sd/koreader/fbink"
CSV="/mnt/sd/quotes.csv"
FONT_DIR="/mnt/sd/koreader/fonts/noto"
REGULAR="$FONT_DIR/NotoSerif-Regular.ttf"
BOLD="$FONT_DIR/NotoSerif-Bold.ttf"
ITALIC="$FONT_DIR/NotoSerif-Italic.ttf"
BOLDITALIC="$FONT_DIR/NotoSerif-BoldItalic.ttf"

while true; do
    # Keep nickel dead
    killall nickel 2>/dev/null
    killall fmon 2>/dev/null

    TIME=$(date +%H:%M)

    # Pick exactly ONE random matching line
    LINE=$(grep "^$TIME|" "$CSV" | awk 'BEGIN{srand()} {lines[NR]=$0} END{if(NR>0) print lines[int(rand()*NR)+1]}')

    # # Fall back to nearest previous time
    # if [ -z "$LINE" ]; then
    #     LINE=$(grep -E "^[0-9]{2}:[0-9]{2}\|" "$CSV" | awk -F'|' -v t="$TIME" '$1 <= t {last=$0} END{print last}')
    # fi

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

    # Full flash refresh every 30 minutes to prevent ghosting
    COUNTER=$(expr $COUNTER + 1)
    if [ $COUNTER -ge 30 ]; then
        $FBINK -f -k
        COUNTER=0
        sleep 1
    fi

    # Night mode between 10pm and 6am
    HOUR=$(date +%H)
    if [ "$HOUR" -ge 22 ] || [ "$HOUR" -lt 6 ]; then
        $FBINK -c -m -M -H -t regular="$REGULAR",bold="$BOLD",italic="$ITALIC",bolditalic="$BOLDITALIC",size=18,top=60,bottom=60,left=50,right=50,padding=BOTH,format "$DISPLAY_TEXT"
    else
        $FBINK -c -m -M -t regular="$REGULAR",bold="$BOLD",italic="$ITALIC",bolditalic="$BOLDITALIC",size=18,top=60,bottom=60,left=50,right=50,padding=BOTH,format "$DISPLAY_TEXT"
    fi

    # $FBINK -c -m -M -t regular="$REGULAR",bold="$BOLD",italic="$ITALIC",bolditalic="$BOLDITALIC",size=18,top=60,bottom=60,left=50,right=50,padding=BOTH,format "$DISPLAY_TEXT"

    SECS=$(date +%S)
    WAIT=$(expr 60 - $SECS)
    sleep $WAIT
done
