#!/bin/bash

# Compulsory test case (b)
# Run this while server.sh IS running.
#
# Client A connects first and delays completing its request.  The server
# creates a per-IP busy lock as soon as the connection is accepted.
# A second request from the same host/IP should receive an explicit
# rejection message.

HOST="${1:-localhost}"
PORT="${2:-1234}"

FIRST_OUT="/tmp/info1112_test02_first_out_$$"
FIRST_ERR="/tmp/info1112_test02_first_err_$$"
SECOND_OUT="/tmp/info1112_test02_second_out_$$"
SECOND_ERR="/tmp/info1112_test02_second_err_$$"

(
    {
        printf "assignment"
        sleep 4
        printf "\n"
    } | nc "$HOST" "$PORT" >"$FIRST_OUT" 2>"$FIRST_ERR"
) &
FIRST_PID=$!

sleep 1

echo "population" | nc -w 3 "$HOST" "$PORT" >"$SECOND_OUT" 2>"$SECOND_ERR" || true

if grep -q "already being processed" "$SECOND_OUT"; then
    echo "PASS: the second request from the same IP was rejected"
    RESULT=0
else
    echo "FAIL: the second request was not rejected as expected"
    echo "Second client response:"
    cat "$SECOND_OUT"
    cat "$SECOND_ERR"
    RESULT=1
fi

wait "$FIRST_PID" 2>/dev/null || true

rm -f "$FIRST_OUT" "$FIRST_ERR" "$SECOND_OUT" "$SECOND_ERR"
exit "$RESULT"
