#!/bin/bash

# Get current dir
pushd $(dirname $0) > /dev/null
cwd=$(pwd)
popd > /dev/null

function callRemote() {
    ssh $SCENARIO_SERVER bash -s << EOF
cd $SCENARIOS_DIR_REMOTE/$SCENARIO_NAME
$@
EOF
}

function banner() {
    echo
    echo "####################################################################################################"
    echo "## $@"
    echo "####################################################################################################"
    echo
}

function checkURL() {
    up=$(curl -s -o /dev/null -w "%{http_code}" $1)
    if [ "$up" != "200" ]; then
        echo "ERROR: $1 is not running (returned $up)"
    else
        echo "OK: $1 is running"
    fi
}

# Scenario vars
SCENARIO_NAME=dev
source .env.$SCENARIO_NAME

STRUCTUR_ZIP=/var/dev/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip
SCENARIOS_DIR_REMOTE=/var/dev/ONCE.2023-Scenarios
SCENARIOS_DIR_LOCAL=$cwd/_scenarios

# Setup scenario dir locally
banner "Setup scenario dir locally"
rm -rf $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
mkdir -p $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
cp -R -a docker-compose.yml scenario.*.sh structr certbot $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/
cp .env.$SCENARIO_NAME $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/.env

# Cleanup remotely
banner "Cleanup remotely"
callRemote ./scenario.cleanup.sh || true

# Sync to remote and call on destination docker host
banner "Sync to remote and call on destination docker host"
ssh $SCENARIO_SERVER bash -s << EOF
mkdir -p $SCENARIOS_DIR_REMOTE/$SCENARIO_NAME
EOF
rsync -avzP --exclude=_data --delete $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/ $SCENARIO_SERVER:$SCENARIOS_DIR_REMOTE/$SCENARIO_NAME/

# Startup WODA with WODA.2023 container and check that startup is done
banner "Startup WODA with WODA.2023 container and check that startup is done"
callRemote ./scenario.install.sh

# Restart once server
banner "Restart once server"
callRemote ./scenario.start.sh

# Check running servers
_scenarios/dev/scenario.test.sh
