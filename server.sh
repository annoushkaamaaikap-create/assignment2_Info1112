#!/bin/bash

# INFO1112 Assignment 2 - TCP server
#
# The request handling is intentionally kept at a beginner Bash level.
# Ncat is only used as the TCP listener because it can start one copy of
# this Bash script for each connection.  This makes the compulsory
# "same IP while busy" rejection reliable.

SERVER_PORT="${SERVER_PORT:-1234}"

ASSIGNMENT_URL="https://www.sydney.edu.au/units/INFO1112/2026-S2C-ND-CC"
POPULATION_URL="https://dbr.abs.gov.au/processedData/csv/STE_1.csv"
NOMINATIM_URL="https://nominatim.openstreetmap.org/search"
OVERPASS_URL="https://overpass-api.de/api/interpreter"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "$0")"


# ------------------------------------------------------------
# Small helper functions
# ------------------------------------------------------------

log_message()
{
    # In client-handler mode stdout goes to the client, so status messages
    # are written to stderr.  They still appear in the server terminal.
    echo "$1" >&2
}

send_error()
{
    echo "error: $1"
    log_message "error: $1"
}

clean_field()
{
    # Remove quotes, spaces and Windows carriage-return characters.
    echo "$1" | tr -d '" \r'
}

get_server_ip()
{
    # Do not hardcode the container IP address.
    ifconfig | awk '
        /inet / {
            for (i = 1; i <= NF; i++) {
                if ($i == "inet") {
                    ip = $(i + 1)
                    sub(/^addr:/, "", ip)
                    if (ip != "127.0.0.1") {
                        print ip
                        exit
                    }
                }
            }
        }
    '
}

get_listening_port()
{
    # Extract the active listener from ss -ltn rather than printing
    # SERVER_PORT directly.
    ss -ltn | awk -v wanted=":$SERVER_PORT" '
        NR > 1 && $4 ~ wanted "$" {
            n = split($4, parts, ":")
            print parts[n]
            exit
        }
    '
}


# ------------------------------------------------------------
# Assignment request
# ------------------------------------------------------------

handle_assignment()
{
    HTML_FILE="$WORK_DIR/assignment.html"
    TEXT_FILE="$WORK_DIR/assignment.txt"
    JSON_FILE="$WORK_DIR/assignment.json"

    log_message "Request: assignment"

    if ! curl -fsSL --max-time 25 "$ASSIGNMENT_URL" -o "$HTML_FILE"; then
        send_error "could not download the INFO1112 webpage"
        return
    fi

    if ! html2text "$HTML_FILE" > "$TEXT_FILE" 2>/dev/null; then
        send_error "could not convert the webpage into text"
        return
    fi

    ASSIGNMENT_BLOCK=$(awk '
        /Assignment 2/ {found = 1}
        found {print}
        found && /Outcomes assessed:/ {exit}
    ' "$TEXT_FILE")

    if [ -z "$ASSIGNMENT_BLOCK" ]; then
        send_error "Assignment 2 information was not found on the webpage"
        return
    fi

    # Extract the values from downloaded text.  The values themselves
    # are not hardcoded in this script.
    TITLE=$(printf '%s\n' "$ASSIGNMENT_BLOCK" |
        grep -o 'Assignment[[:space:]][0-9][0-9]*' | head -n 1)

    TOPIC=$(printf '%s\n' "$ASSIGNMENT_BLOCK" |
        sed -n 's/.*Programming task[[:space:]]*-[[:space:]]*\([^|]*\).*/\1/p' |
        head -n 1 |
        sed 's/[[:space:]]*$//; s/[[:space:]][[:space:]]*[0-9][0-9]*%.*//')

    # Figure 9 uses the short topic name "Networking".  Keep the first
    # word from the topic extracted from the webpage.
    TOPIC=$(echo "$TOPIC" | awk '{print $1}')

    POINTS=$(printf '%s\n' "$ASSIGNMENT_BLOCK" |
        grep -o '[0-9][0-9]*%' | head -n 1 | tr -d '%')

    DUE_DATE=$(printf '%s\n' "$ASSIGNMENT_BLOCK" |
        sed -n 's/.*Due date:[[:space:]]*//p' | head -n 1 |
        sed 's/[[:space:]]*|.*//; s/[[:space:]]at[[:space:]]/ /')

    if [ -z "$TITLE" ] || [ -z "$TOPIC" ] || [ -z "$POINTS" ] || [ -z "$DUE_DATE" ]; then
        send_error "could not extract all Assignment 2 fields from the webpage"
        return
    fi

    log_message "----------------------------------------"
    log_message "Assignment information"
    log_message "Title    : $TITLE"
    log_message "Topic    : $TOPIC"
    log_message "Due date : $DUE_DATE"
    log_message "Points   : $POINTS"
    log_message "----------------------------------------"

    cat > "$JSON_FILE" <<JSON
{
  "title": "$TITLE",
  "topic": "$TOPIC",
  "due_date": "$DUE_DATE",
  "points": $POINTS
}
JSON

    # stdout is the TCP response in handler mode.
    cat "$JSON_FILE"
}


# ------------------------------------------------------------
# Population request
# ------------------------------------------------------------

handle_population()
{
    CSV_FILE="$WORK_DIR/STE_1.csv"
    DATA_FILE="$WORK_DIR/population_data.csv"
    PNG_FILE="$WORK_DIR/population.png"

    log_message "Request: population"

    if ! curl -fsSL --max-time 30 "$POPULATION_URL" -o "$CSV_FILE"; then
        send_error "could not download the ABS population CSV file"
        return
    fi

    # The ABS Data by Region file uses ERP_P_20 for estimated resident
    # population.  Bash reads the year headings and values.
    HEADER_LINE=$(grep -m 1 -i '^"*MEASURE' "$CSV_FILE")
    POPULATION_LINE=$(grep -m 1 'ERP_P_20' "$CSV_FILE")

    if [ -z "$HEADER_LINE" ]; then
        HEADER_LINE=$(head -n 1 "$CSV_FILE")
    fi

    if [ -z "$POPULATION_LINE" ]; then
        send_error "could not find the estimated resident population row in the CSV file"
        return
    fi

    IFS=',' read -r -a HEADERS <<< "$HEADER_LINE"
    IFS=',' read -r -a VALUES <<< "$POPULATION_LINE"

    : > "$DATA_FILE"

    i=0
    while [ $i -lt ${#HEADERS[@]} ]; do
        YEAR=$(clean_field "${HEADERS[$i]}")
        VALUE=$(clean_field "${VALUES[$i]}")

        if echo "$YEAR" | grep -Eq '^(19|20)[0-9][0-9]$' && \
           echo "$VALUE" | grep -Eq '^[0-9]+([.][0-9]+)?$'; then
            echo "$YEAR,$VALUE" >> "$DATA_FILE"
        fi

        i=$((i + 1))
    done

    if [ ! -s "$DATA_FILE" ]; then
        send_error "could not extract year and population data from the CSV file"
        return
    fi

    LATEST_LINE=$(tail -n 1 "$DATA_FILE")
    LATEST_YEAR=${LATEST_LINE%%,*}
    LATEST_POPULATION=${LATEST_LINE#*,}

    log_message "Latest NSW population ($LATEST_YEAR): $LATEST_POPULATION"

    if ! python3 "$SCRIPT_DIR/plot_population.py" "$DATA_FILE" "$PNG_FILE"; then
        send_error "could not generate population.png"
        return
    fi

    if [ ! -s "$PNG_FILE" ]; then
        send_error "population.png was not created"
        return
    fi

    log_message "population.png generated and sent to the client"

    # Send only the PNG bytes to the client.
    cat "$PNG_FILE"
}


# ------------------------------------------------------------
# POI / where-am-I request
# ------------------------------------------------------------

handle_poi()
{
    INPUT="$1"
    LOCATION_JSON="$WORK_DIR/location.json"
    POI_JSON="$WORK_DIR/neighboring_pois.json"

    # Support either a raw POI value or an optional "poi " prefix.
    INPUT=$(echo "$INPUT" | sed 's/^poi[[:space:]][[:space:]]*//')

    if [ -z "$INPUT" ]; then
        send_error "no POI name or coordinates were supplied"
        return
    fi

    log_message "Request: POI - $INPUT"

    COORDINATES=$(echo "$INPUT" | tr -d ' ')

    if echo "$COORDINATES" | grep -Eq '^-?[0-9]+([.][0-9]+)?,-?[0-9]+([.][0-9]+)?$'; then
        LATITUDE=${COORDINATES%%,*}
        LONGITUDE=${COORDINATES#*,}
    else
        # Convert a place name to coordinates using Nominatim.
        if ! curl -fsS --max-time 25 \
            -A "INFO1112-Assignment2/1.0" \
            -G "$NOMINATIM_URL" \
            --data-urlencode "q=$INPUT" \
            --data "format=jsonv2" \
            --data "limit=1" \
            -o "$LOCATION_JSON"; then
            send_error "could not look up the POI name"
            return
        fi

        LATITUDE=$(sed -n 's/.*"lat":"\([^"]*\)".*/\1/p' "$LOCATION_JSON" | head -n 1)
        LONGITUDE=$(sed -n 's/.*"lon":"\([^"]*\)".*/\1/p' "$LOCATION_JSON" | head -n 1)

        if [ -z "$LATITUDE" ] || [ -z "$LONGITUDE" ]; then
            send_error "the POI name could not be resolved to coordinates"
            return
        fi
    fi

    log_message "POI coordinates: $LATITUDE,$LONGITUDE"

    # The PDF does not specify a POI service or radius.  This solution
    # uses common OSM POI categories within 1000 metres.
    OVERPASS_QUERY="[out:json][timeout:25];(nwr(around:1000,$LATITUDE,$LONGITUDE)[amenity];nwr(around:1000,$LATITUDE,$LONGITUDE)[shop];nwr(around:1000,$LATITUDE,$LONGITUDE)[tourism];nwr(around:1000,$LATITUDE,$LONGITUDE)[leisure];);out center;"

    if ! curl -fsS --max-time 35 \
        -G "$OVERPASS_URL" \
        --data-urlencode "data=$OVERPASS_QUERY" \
        -o "$POI_JSON"; then
        send_error "could not download neighboring POIs"
        return
    fi

    if [ ! -s "$POI_JSON" ]; then
        send_error "no POI JSON data was returned"
        return
    fi

    log_message "Neighboring POIs returned to the client"
    cat "$POI_JSON"
}


# ------------------------------------------------------------
# Per-client handler
# ------------------------------------------------------------

handle_client()
{
    CLIENT_IP="${NCAT_REMOTE_ADDR:-unknown}"

    # A lock directory is atomic: only the first request from this IP
    # can create it.  A second simultaneous request from the same IP is
    # therefore rejected immediately.
    SAFE_IP=$(echo "$CLIENT_IP" | tr '.:' '__')
    LOCK_DIR="/tmp/info1112_busy_$SAFE_IP"

    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        log_message "Rejected second request from $CLIENT_IP because the client is busy"
        echo "error: another request from $CLIENT_IP is already being processed"
        return 1
    fi

    WORK_DIR=$(mktemp -d "/tmp/info1112_client_${SAFE_IP}_XXXXXX")

    cleanup_client()
    {
        rm -rf "$WORK_DIR" "$LOCK_DIR"
    }

    trap cleanup_client EXIT INT TERM

    log_message "Connection received on $CLIENT_IP"

    if ! IFS= read -r REQUEST; then
        send_error "could not read a request from the client"
        return 1
    fi

    case "$REQUEST" in
        assignment|asssignment)
            handle_assignment
            ;;

        population)
            handle_population
            ;;

        "")
            send_error "empty request"
            ;;

        *)
            # Any other non-empty request is treated as a POI name
            # or a latitude,longitude pair.
            handle_poi "$REQUEST"
            ;;
    esac
}


# ------------------------------------------------------------
# Main server
# ------------------------------------------------------------

run_server()
{
    for command_name in ncat ifconfig ss curl html2text awk sed grep python3
    do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            echo "error: required command '$command_name' is not installed"
            echo "Run setup_alpine.sh inside the Alpine container first."
            exit 1
        fi
    done

    # Remove stale per-IP locks left by an abnormal previous shutdown.
    rm -rf /tmp/info1112_busy_* 2>/dev/null || true

    # Ncat keeps listening and starts this same script in --handle-client
    # mode for every TCP connection.
    ncat -4 -l "$SERVER_PORT" --keep-open \
        --sh-exec "bash \"$SCRIPT_PATH\" --handle-client" &
    NCAT_PID=$!

    cleanup_server()
    {
        kill "$NCAT_PID" 2>/dev/null || true
        wait "$NCAT_PID" 2>/dev/null || true
    }

    trap cleanup_server EXIT INT TERM

    sleep 0.3

    if ! kill -0 "$NCAT_PID" 2>/dev/null; then
        echo "error: the TCP listener could not be started"
        exit 1
    fi

    SERVER_IP=$(get_server_ip)
    LISTENING_PORT=$(get_listening_port)

    if [ -z "$SERVER_IP" ]; then
        echo "error: could not determine server IP address using ifconfig"
        exit 1
    fi

    if [ -z "$LISTENING_PORT" ]; then
        echo "error: could not determine listening port using ss -ltn"
        exit 1
    fi

    echo "The server is running at Link addr:$SERVER_IP, port=$LISTENING_PORT"
    echo "Listening on 0.0.0.0 $LISTENING_PORT"

    # Wait forever until the user stops the server with Ctrl+C.
    wait "$NCAT_PID"
}


# Internal mode used by Ncat for one connection.
if [ "$1" = "--handle-client" ]; then
    handle_client
    exit $?
fi

if [ $# -gt 0 ]; then
    echo "usage: bash server.sh"
    exit 1
fi

run_server
