#!/bin/bash

source .env.$1

function checkURL() {
    up=$(curl -s -o /dev/null -w "%{http_code}" $1)
    if [ "$up" != "200" ]; then
        echo "ERROR: $1 is not running (returned $up)"
    else
        echo "OK: $1 is running"
    fi
}

function banner() {
    echo
    echo "--- $1"
    echo
}

# Check running servers
banner "Check running servers"
checkURL http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/
checkURL http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/apps/neom/CityManagement.html
checkURL https://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTPS/EAMD.ucp/
checkURL http://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTP/structr/
checkURL https://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTPS/structr/
