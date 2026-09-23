#!/bin/sh
# Integrity check for quotes.csv. There is no build or test suite in this
# project, so this is what stands in for one: it catches the dataset faults
# that litclock.sh cannot report, because on-device they fail silently.
#
#   ./tools/validate_quotes.sh [quotes.csv]
#
# Exits non-zero if anything is wrong. Safe to run anywhere (no device needed).

CSV="${1:-quotes.csv}"

if [ ! -f "$CSV" ]; then
    echo "validate: no such file: $CSV" >&2
    exit 2
fi

awk -F'|' -v csv="$CSV" '
function flag(msg) { printf "  %s:%d: %s\n", csv, NR, msg; bad++ }

{
    rows++

    # 1. Field count. A row with extra pipes means two records were joined by a
    #    lost newline: the quote gets truncated and the book/author come out of
    #    the wrong record.
    if (NF != 5) { flag("expected 5 fields, found " NF); next }

    # 2. Timestamp must be a real HH:MM, since litclock.sh greps "^HH:MM|".
    if ($1 !~ /^[0-2][0-9]:[0-5][0-9]$/ || $1 + 0 > 23) {
        flag("bad timestamp: [" $1 "]"); next
    }
    seen[$1] = 1

    # 3. Every field must be non-empty.
    for (i = 1; i <= 5; i++)
        if ($i ~ /^[[:space:]]*$/) flag("field " i " is empty")

    # 4. The time phrase must occur verbatim in the quote, or the highlight
    #    substitution silently does nothing and the phrase renders unemphasised.
    if (index($3, $2) == 0)
        flag("time phrase [" $2 "] does not occur in the quote")

    # 5. fbink is invoked with format=, which reads * / ** / *** as emphasis.
    #    A stray asterisk in the text garbles the rendering.
    if ($3 ~ /\*/) flag("quote contains a literal '\''*'\'' (fbink format markup)")

    # 6. Leftover markup from the source dataset.
    if ($3 ~ /<[a-zA-Z\/]/) flag("quote contains an HTML tag")

    if (dupe[$0]++) flag("exact duplicate of an earlier row")
}

END {
    # 7. Minutes with no quote fall back to "Time passes. HH:MM".
    for (h = 0; h < 24; h++)
        for (m = 0; m < 60; m++) {
            k = sprintf("%02d:%02d", h, m)
            if (!(k in seen)) { missing++; gap = gap " " k }
        }

    printf "%d rows, %d of 1440 minutes covered\n", rows, 1440 - missing
    if (missing > 0) printf "\nuncovered minutes (%d), these render the generic fallback:%s\n", missing, gap
    if (bad > 0) { printf "\nFAIL: %d problem(s)\n", bad; exit 1 }
    printf "OK: no structural problems\n"
}
' "$CSV"
