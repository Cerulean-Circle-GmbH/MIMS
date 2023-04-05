#!/bin/bash

# Get current dir
pushd $(dirname $0) > /dev/null
cwd=$(pwd)
popd > /dev/null

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
if [ -z "$1" || -z "$2" ]; then
    echo "Usage: $0 <scenario> (int|test)"
    echo "Example: $0 dev test"
    exit 1
fi
SCENARIO_NAME=$1
source .env.$SCENARIO_NAME
source src/structr/.env
SCENARIOS_DIR_LOCAL=$cwd/_scenarios

function init() {
    # Setup scenario dir locally
    banner "Setup scenario dir locally"
    rm -rf $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
    mkdir -p $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
    cp -R -a src/* $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/
    ENVIROMENT_VARIABLES=$(echo SCENARIO_NAME && cat .env.$SCENARIO_NAME structr/.env | grep -v ^# | grep -v ^$ | sed "s/=.*//")
    for ENV_VAR in $ENVIROMENT_VARIABLES; do
        echo "$ENV_VAR=${!ENV_VAR}"
    done > $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/.env

    # Sync to remote and call on destination docker host
    banner "Sync to remote and call on destination docker host"
        ssh $SCENARIO_SERVER bash -s << EOF
        mkdir -p $SCENARIOS_DIR_REMOTE/$SCENARIO_NAME
EOF
    rsync -avzP --exclude=_data --delete $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/ $SCENARIO_SERVER:$SCENARIOS_DIR_REMOTE/$SCENARIO_NAME/
}

fucntion test() {
    # Check running servers
    banner "Check running servers"
    checkURL http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/
    checkURL http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/apps/neom/CityManagement.html
    checkURL https://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTPS/EAMD.ucp/
    checkURL http://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTP/structr/
    checkURL https://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTPS/structr/

    # Check EAMD.ucp git status
    banner "Check EAMD.ucp git status for $SCENARIO_SERVER - $SCENARIO_NAME"
    # TODO: Put more data into git-status.log (5 links, .env, .once)
    curl http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/git-status.log
    # TODO: Check .once variable
    # curl http://backup.sfsre.com:9080/EAMD.ucp/Scenarios/local/docker/d116a5682395/vhosts/localhost/EAM/1_infrastructure/Once/latestServer/.once.env
}

$2