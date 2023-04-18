#!/bin/bash

# Get current dir
pushd $(dirname $0) > /dev/null
cwd=$(pwd)
popd > /dev/null

# Check for keyfile
if [[ -n "${keyfile}" ]]; then
    echo "Use ${keyfile}"
    use_key="-i ${keyfile}"
fi

function banner() {
    echo
    echo "####################################################################################################"
    echo "## $@"
    echo "####################################################################################################"
    echo
}

function callRemote() {
    ssh $use_key -o 'StrictHostKeyChecking no' $SCENARIO_SSH_CONFIG bash -s << EOF
cd $SCENARIOS_DIR/$SCENARIO_NAME
$@
EOF
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
    echo "Usage: $0 <scenario> [init] [up] [start] [stop] [down] [test] [remove]"
    echo
    echo "          init   - init remote scenario dir"
    echo "          up     - Create and start scenario"
    echo "          start  - Start scenario if already created"
    echo "          stop   - Stop scenario"
    echo "          down   - Stop and shut down scenario"
    echo "          test   - Test the running scenario"
    echo "          remove - Remove all remote and local scenario dir"
    echo
    echo "Example: $0 dev (defaults to: init stop up test)"
    echo "Example: $0 dev stop start"
    echo "Example: $0 dev init stop up start test"
    echo "Example: $0 dev init down remove"
    echo
    echo "Available scenarios:"
    ls .env.* | sed "s/.env./    /" | sed "s/ /\\ /g"
    exit 1
fi
SCENARIO_NAME=$1
shift
if [ ! -f .env.$SCENARIO_NAME ]; then
    echo "ERROR: Scenario .env.$SCENARIO_NAME not found"
    exit 1
fi
source .env.$SCENARIO_NAME
OTHER_ENV_FILES=$(find $SCENARIO_COMPONENT_DIR -name .env)
for OTHER_ENV_FILE in $OTHER_ENV_FILES; do
    source $OTHER_ENV_FILE
done
SCENARIOS_DIR_LOCAL=$cwd/_scenarios
if [ -z "$SCENARIO_SSH_CONFIG" ]; then
    SCENARIO_SSH_CONFIG=$SCENARIO_SERVER
fi

function init() {
    # Setup scenario dir locally
    banner "Setup scenario dir locally and sync to remote"
    rm -rf $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
    mkdir -p $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
    cp -R -a $SCENARIO_COMPONENT_DIR/* $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/
    ENVIROMENT_VARIABLES=$(echo SCENARIO_NAME && cat .env.$SCENARIO_NAME $OTHER_ENV_FILES | grep -v ^# | grep -v ^$ | sed "s/=.*//")
    for ENV_VAR in $ENVIROMENT_VARIABLES; do
        echo "$ENV_VAR=${!ENV_VAR}"
    done > $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/.env

    # Sync to remote
    ssh $use_key -o 'StrictHostKeyChecking no' $SCENARIO_SSH_CONFIG bash -s << EOF
        mkdir -p $SCENARIOS_DIR/$SCENARIO_NAME
EOF
    rsync -avzP --exclude=_data --delete -e "ssh $use_key -o 'StrictHostKeyChecking no'" $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/ $SCENARIO_SSH_CONFIG:$SCENARIOS_DIR/$SCENARIO_NAME/
}

function up() {
    init

    # Startup WODA with WODA.2023 container and check that startup is done
    banner "Startup WODA with WODA.2023 container and check that startup is done"
    callRemote ./scenario.sh up
}

function start() {
    # Restart once server
    banner "Restart once server"
    callRemote ./scenario.sh start
}

function stop() {
    # Stop remotely
    banner "Stop remotely"
    callRemote ./scenario.sh stop || true
}

function down() {
    init

    # Shutdown remotely
    banner "Shutdown remotely"
    callRemote ./scenario.sh down || true
}

function remove() {
    down

    # Remove locally and remotely
    banner "Remove locally and remotely"
    rm -rf $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
    rmdir $SCENARIOS_DIR_LOCAL 2>/dev/null || true
    ssh $use_key -o 'StrictHostKeyChecking no' $SCENARIO_SSH_CONFIG bash -s << EOF
cd $SCENARIOS_DIR && rm -rf $SCENARIO_NAME
EOF
}

function test() {
    # Test remote
    banner "Test remote"
    callRemote ./scenario.sh test
}

DEFAULT_STEPS="init stop up test"
if [ -z "$1" ]; then
    STEPS=$DEFAULT_STEPS
else
    STEPS=$@
fi

for STEP in $STEPS; do
    if [ "$STEP" == "init" ]; then
        init
    elif [ "$STEP" == "up" ]; then
        up
    elif [ "$STEP" == "start" ]; then
        start
    elif [ "$STEP" == "stop" ]; then
        stop
    elif [ "$STEP" == "down" ]; then
        down
    elif [ "$STEP" == "remove" ]; then
        remove
    elif [ "$STEP" == "test" ]; then
        test
    else
        echo "ERROR: Unknown step: $STEP"
        exit 1
    fi
done
