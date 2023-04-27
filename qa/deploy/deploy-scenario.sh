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
    ssh $use_key -o 'StrictHostKeyChecking no' $SCENARIO_SERVER_SSHCONFIG bash -s << EOF
cd $SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME
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

# Usage
if [ -z "$1" ]; then
    echo "Usage: $0 <scenario> [init,updateconfig,up,start,stop,down,test,remove]"
    echo
    echo "          init   - init remote scenario dir"
    echo "          updateconfig - update local scenario config"
    echo "          up     - Create and start scenario"
    echo "          start  - Start scenario if already created"
    echo "          stop   - Stop scenario"
    echo "          down   - Stop and shut down scenario"
    echo "          test   - Test the running scenario"
    echo "          remove - Remove all remote and local scenario dir"
    echo
    echo "Example: $0 dev (defaults to: up,test)"
    echo "Example: $0 dev stop,start"
    echo "Example: $0 dev up"
    echo "Example: $0 dev remove"
    echo
    echo "* up will call init and stop"
    echo "* down will call init"
    echo "* remove will call down"
    echo
    echo "Available scenarios:"
    cd $cwd && find Scenarios -name *.scenario | sed "s;Scenarios/;    ;" | sed "s/\.scenario//" | sed "s/ /\\ /g"
    exit 1
fi
SCENARIO_NAME=$(basename $1)
SCENARIO_NAME_SPACE=$(dirname $1)
SCENARIO_FILE_NAME=$cwd/Scenarios/$SCENARIO_NAME_SPACE/$SCENARIO_NAME.scenario
SCENARIO_FILE_NAME_TMP=$SCENARIO_FILE_NAME.tmp
SCENARIOS_DIR_LOCAL=$cwd/_scenarios
shift

# ask with default
function ask_with_default {
    read -p "$1 [$2]: " answer
    if [[ -z "$answer" ]]; then
        echo "$2"
    else
        echo "$answer"
    fi
}

# Compatibility adaption (convert old env version to new one)
function getVarFromOldVar() {
    local newVar=$1
    local oldVar=$2
    if [ -z "${!newVar}" ]; then
        eval "$newVar=\$$oldVar"
    fi
}

# Source env files
function sourceEnv() {
    # Source scenario env file
    if [ -f $SCENARIO_FILE_NAME ]; then
        source $SCENARIO_FILE_NAME
    fi

    # Source scenario env file (tmp)
    if [ -f $SCENARIO_FILE_NAME_TMP ]; then
        source $SCENARIO_FILE_NAME_TMP
    fi

    # Set missing variables resp. compatibility adaption (convert old env version to new one)
    getVarFromOldVar SCENARIO_SSH_CONFIG                SCENARIO_SERVER
    getVarFromOldVar SCENARIO_SRC_TAG                   SCENARIO_TAG
    getVarFromOldVar SCENARIO_SRC_BRANCH                SCENARIO_BRANCH
    getVarFromOldVar SCENARIO_SRC_STRUCTRDATAFILE       SCENARIO_STRUCTR_DATA_SRC_FILE
    getVarFromOldVar SCENARIO_SRC_COMPONENT             SCENARIO_COMPONENT_DIR
    getVarFromOldVar SCENARIO_SERVER_NAME               SCENARIO_SERVER
    getVarFromOldVar SCENARIO_SERVER_SSHCONFIG          SCENARIO_SSH_CONFIG
    getVarFromOldVar SCENARIO_SERVER_CONFIGSDIR         SCENARIOS_DIR
    getVarFromOldVar SCENARIO_SERVER_CERTIFICATEDIR     SCENARIO_CERTIFICATE_DIR
    getVarFromOldVar SCENARIO_RESOURCE_ONCE_HTTP        SCENARIO_ONCE_HTTP
    getVarFromOldVar SCENARIO_RESOURCE_ONCE_HTTPS       SCENARIO_ONCE_HTTPS
    getVarFromOldVar SCENARIO_RESOURCE_ONCE_SSH         SCENARIO_ONCE_SSH
    getVarFromOldVar SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTP       SCENARIO_ONCE_REVERSE_PROXY_HTTP_PORT
    getVarFromOldVar SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS      SCENARIO_ONCE_REVERSE_PROXY_HTTPS_PORT
    getVarFromOldVar SCENARIO_RESOURCE_STRUCTR_HTTP     SCENARIO_STRUCTR_HTTP
    getVarFromOldVar SCENARIO_RESOURCE_STRUCTR_HTTPS    SCENARIO_STRUCTR_HTTPS

    # Source other env files from component definition
    OTHER_ENV_FILES=$(find $cwd/Components/$SCENARIO_SRC_COMPONENT -name .env)
    for OTHER_ENV_FILE in $OTHER_ENV_FILES; do
        source $OTHER_ENV_FILE
    done
}

sourceEnv

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" \
        -e "s|$s\(##*\)$s\(.*\)\$|\1 \2|p" $1 |
   awk -F$fs '{
      if ( $1 ~ /#.*/ ) {
        if ( $1 ~ /##.*/ ) {
          print("")
        }
        print($1);
      } else {
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=\"%s\"\n", "'$prefix'", toupper(vn), toupper($2), $3);
        }
      }
   }'
}

function doCopyConfig() {
    cp -f $SCENARIO_FILE_NAME_TMP $SCENARIO_FILE_NAME
    echo "Please check $SCENARIO_FILE_NAME and commit it to git."
}

function updateconfig() {
    config
    doCopyConfig
}

function config() {
    sourceEnv

    # Configure scenario
    banner "Configure scenario"

    mkdir -p $cwd/Scenarios/$SCENARIO_NAME_SPACE

    if [ -z "$SCENARIO_SRC_COMPONENT" ]; then
        echo "Available component dirs:"
        cd $cwd && find Components -name defaults.scenario.yaml | sed "s;Components/;    ;" | sed "s/.defaults.scenario.yaml//" | sed "s/ /\\ /g"
        SCENARIO_SRC_COMPONENT=$(ask_with_default "Choose available component dir  :" "")
    fi

    # Convert defaults.scenario.yaml > _defaults.scenario.sh
    SCENARIO_DEFAULTS_YAML=$cwd/Components/$SCENARIO_SRC_COMPONENT/defaults.scenario.yaml
    SCENARIO_DEFAULTS_ENV=$cwd/Components/$SCENARIO_SRC_COMPONENT/_defaults.scenario.sh
    parse_yaml $SCENARIO_DEFAULTS_YAML > $SCENARIO_DEFAULTS_ENV

    # Check $SCENARIO_FILE_NAME for missing variables
    local current_comment=""
    local i_had_to_ask=false
    rm -rf $SCENARIO_FILE_NAME_TMP
    IFS=$'\n'
    for line in $(cat "$SCENARIO_DEFAULTS_ENV"); do
        if echo "$line" | grep -q "="; then
            local variable=$(echo "$line" | cut -d "=" -f 1)
            local default=$(echo "$line" | cut -d "=" -f 2 | sed "s/^\"//" | sed "s/\"$//")
            local value=${!variable}
            #echo
            #echo "current_comment : \"$current_comment\""
            #echo "variable        : \"$variable\""
            #echo "default         : \"$default\""
            #echo "value           : \"$value\""
            if [ -z "$value" ]; then
                value=$(ask_with_default "$current_comment" "$default")
                #echo "I ASKED AND GOT : \"$value\""
                i_had_to_ask=true
            fi
            echo "$variable=\"$value\"" >> $SCENARIO_FILE_NAME_TMP
        else
            echo $line >> $SCENARIO_FILE_NAME_TMP
            if [[ $line =~ ^[[:space:]]*# ]]; then
                current_comment=$(echo "$line" | sed "s/^[[:space:]]*#[[:space:]]*//")
            fi
        fi
    done
    unset IFS

    # Update $SCENARIO_FILE_NAME if needed
    if [ "$i_had_to_ask" = true ]; then
        # TODO: Find another way to also ask if variables should be updated or are removed
        echo
        echo "I had to ask for some variables."
        SURE=$(ask_with_default "Should I update the scenario with the new values? (yes/no)?" "no")
        if [ -z `echo $SURE | grep -i y` ]; then
            echo "Not updated."
        else
            doCopyConfig
        fi
    fi

    # Source all variables (again) in case changes were made
    sourceEnv
}

function init() {
    config

    # Setup scenario dir locally
    banner "Setup scenario dir locally and sync to remote"
    rm -rf $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME_SPACE/$SCENARIO_NAME
    mkdir -p $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME_SPACE/$SCENARIO_NAME
    cp -R -a $cwd/Components/$SCENARIO_SRC_COMPONENT/* $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME_SPACE/$SCENARIO_NAME/
    ENVIROMENT_VARIABLES=$(echo SCENARIO_NAME && echo SCENARIO_NAME_SPACE && cat $SCENARIO_FILE_NAME_TMP $OTHER_ENV_FILES | grep -v ^# | grep -v ^$ | sed "s/=.*//")
    for ENV_VAR in $ENVIROMENT_VARIABLES; do
        echo "$ENV_VAR=${!ENV_VAR}"
    done > $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME_SPACE/$SCENARIO_NAME/.env

    # Sync to remote
    echo "ssh $use_key -o 'StrictHostKeyChecking no' $SCENARIO_SERVER_SSHCONFIG ls $SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME"
    ssh $use_key -o 'StrictHostKeyChecking no' $SCENARIO_SERVER_SSHCONFIG ls $SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME
    ssh $use_key -o 'StrictHostKeyChecking no' $SCENARIO_SERVER_SSHCONFIG bash -s << EOF
        mkdir -p $SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME
EOF
    rsync -avzP --exclude=_data --delete -e "ssh $use_key -o 'StrictHostKeyChecking no'" $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME_SPACE/$SCENARIO_NAME/ $SCENARIO_SERVER_SSHCONFIG:$SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME/
}

function up() {
    init
    stop

    # Startup WODA with WODA.2023 container and check that startup is done
    banner "Startup WODA with WODA.2023 container and check that startup is done"
    callRemote ./scenario.sh up
}

function start() {
    if [ ! -f $SCENARIO_FILE_NAME ]; then
        echo "ERROR: Scenario $SCENARIO_FILE_NAME not found"
        exit 1
    fi

    # Restart once server
    banner "Restart once server"
    callRemote ./scenario.sh start
}

function stop() {
    if [ ! -f $SCENARIO_FILE_NAME ]; then
        echo "ERROR: Scenario $SCENARIO_FILE_NAME not found"
        exit 1
    fi

    # Stop remotely
    banner "Stop remotely"
    callRemote ./scenario.sh stop || true
}

function down() {
    if [ ! -f $SCENARIO_FILE_NAME ]; then
        echo "ERROR: Scenario $SCENARIO_FILE_NAME not found"
        exit 1
    fi

    init

    # Shutdown remotely
    banner "Shutdown remotely"
    callRemote ./scenario.sh down || true
}

function remove() {
    if [ ! -f $SCENARIO_FILE_NAME ]; then
        echo "ERROR: Scenario $SCENARIO_FILE_NAME not found"
        exit 1
    fi

    down

    # Remove locally and remotely
    banner "Remove locally and remotely"
    rm -rf $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME_SPACE/$SCENARIO_NAME
    rmdir -p $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME_SPACE 2>/dev/null || true
    ssh $use_key -o 'StrictHostKeyChecking no' $SCENARIO_SERVER_SSHCONFIG bash -s << EOF
cd $SCENARIO_SERVER_CONFIGSDIR
rm -rf $SCENARIO_NAME_SPACE/$SCENARIO_NAME
rmdir -p $SCENARIO_NAME_SPACE 2>/dev/null || true
EOF
}

function test() {
    if [ ! -f $SCENARIO_FILE_NAME ]; then
        echo "ERROR: Scenario $SCENARIO_FILE_NAME not found"
        exit 1
    fi

    init

    # Test remote
    banner "Test remote"
    callRemote ./scenario.sh test
}

DEFAULT_STEPS="test"
if [ -z "$1" ]; then
    STEPS=$DEFAULT_STEPS
else
    STEPS=$@
fi

for STEP in $(echo $STEPS | sed "s/,/ /g"); do
    if [ "$STEP" == "init" ]; then
        init
    elif [ "$STEP" == "updateconfig" ]; then
        updateconfig
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
