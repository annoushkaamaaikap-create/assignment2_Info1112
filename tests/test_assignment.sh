#!/bin/bash

# Optional functional test for the assignment request.
# Run while server.sh is running.

HOST="${1:-localhost}"
PORT="${2:-1234}"
OUTPUT="assignment.json"

echo "assignment" | nc "$HOST" "$PORT" > "$OUTPUT"

if [ ! -s "$OUTPUT" ]; then
    echo "FAIL: $OUTPUT is empty"
    exit 1
fi

if grep -q '"title"' "$OUTPUT" && \
   grep -q '"topic"' "$OUTPUT" && \
   grep -q '"due_date"' "$OUTPUT" && \
   grep -q '"points"' "$OUTPUT"; then
    echo "PASS: assignment.json was received"
    cat "$OUTPUT"
    exit 0
else
    echo "FAIL: response does not look like assignment.json"
    cat "$OUTPUT"
    exit 1
fi
