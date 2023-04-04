#!/bin/bash

function banner() {
    echo
    echo "--- $1"
    echo
}

function checkURL() {
    up=$(curl -k -s -o /dev/null -w "%{http_code}" $1)
    if [ "$up" != "200" ]; then
        echo "ERROR: $1 is not running (returned $up)"
    else
        echo "OK: running: $1"
    fi
}

# Scenario vars
if [ -z "$1" ]; then
    echo "Usage: $0 <scenario>"
    echo "Example: $0 dev"
    exit 1
fi
SCENARIO_NAME=$1
source .env.$SCENARIO_NAME

# Check running servers
banner "Check running servers"
checkURL http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/
checkURL http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/apps/neom/CityManagement.html
checkURL https://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTPS/EAMD.ucp/
checkURL http://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTP/structr/
checkURL https://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTPS/structr/

# Check EAMD.ucp git status
banner "Check EAMD.ucp git status for $SCENARIO_SERVER - $SCENARIO_NAME"
curl http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/git-status.log