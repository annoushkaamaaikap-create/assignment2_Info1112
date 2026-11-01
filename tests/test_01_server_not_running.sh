#!/bin/bash

# Compulsory test case (a)
# Run this while server.sh is NOT running.

HOST="${1:-localhost}"
PORT="${2:-1234}"

OUTPUT_FILE="/tmp/info1112_test01_output_$$"
ERROR_FILE="/tmp/info1112_test01_error_$$"

if echo "assignment" | nc -w 1 "$HOST" "$PORT" >"$OUTPUT_FILE" 2>"$ERROR_FILE"; then
    echo "FAIL: nc connected even though the server was expected to be stopped"
    rm -f "$OUTPUT_FILE" "$ERROR_FILE"
    exit 1
else
    echo "PASS: nc returned an error because the server is not running"
    cat "$ERROR_FILE"
    rm -f "$OUTPUT_FILE" "$ERROR_FILE"
    exit 0
fi
