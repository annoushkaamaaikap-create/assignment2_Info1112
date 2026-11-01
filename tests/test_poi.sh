#!/bin/bash

# Optional functional test for the "where am I?" request.
# Run while server.sh is running.

HOST="${1:-localhost}"
PORT="${2:-1234}"
POI="${3:-Sydney Opera House}"
OUTPUT="neighboring_pois.json"

echo "$POI" | nc "$HOST" "$PORT" > "$OUTPUT"

if [ ! -s "$OUTPUT" ]; then
    echo "FAIL: $OUTPUT is empty"
    exit 1
fi

if grep -q '"elements"' "$OUTPUT"; then
    echo "PASS: neighboring POI JSON was received"
    exit 0
else
    echo "FAIL: response does not look like Overpass JSON"
    head "$OUTPUT"
    exit 1
fi
