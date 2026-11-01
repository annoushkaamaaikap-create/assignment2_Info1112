#!/bin/bash

# Optional functional test for the population request.
# Run while server.sh is running.

HOST="${1:-localhost}"
PORT="${2:-1234}"
OUTPUT="population.png"

echo "population" | nc "$HOST" "$PORT" > "$OUTPUT"

if [ ! -s "$OUTPUT" ]; then
    echo "FAIL: $OUTPUT is empty"
    exit 1
fi

# A PNG begins with the hexadecimal bytes 89 50 4e 47.
SIGNATURE=$(od -An -tx1 -N4 "$OUTPUT" | tr -d ' \n')

if [ "$SIGNATURE" = "89504e47" ]; then
    echo "PASS: population.png was received"
    exit 0
else
    echo "FAIL: response is not a PNG file"
    head "$OUTPUT"
    exit 1
fi
