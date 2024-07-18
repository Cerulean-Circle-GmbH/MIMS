#!/bin/bash

# Get current dir
pushd $(dirname $0) > /dev/null
cwd=$(pwd)
popd > /dev/null

# Log verbose
function logVerbose() {
    # Check for verbosity not equal to -v
    if [ "$VERBOSITY" != "-v" ]; then
        return
    fi
    echo "$@"
}

# Log
function log() {
    if [ "$VERBOSITY" == "-s" ]; then
        return
    fi
    echo "$@"
}

# Banner
function banner() {
    logVerbose
    logVerbose "####################################################################################################"
    logVerbose "## $@"
    logVerbose "####################################################################################################"
    logVerbose
}

# Call remote function
function callRemote() {
    ssh $use_key -o 'StrictHostKeyChecking no' $SCENARIO_SERVER_SSHCONFIG bash -s << EOF
cd $SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME
$@
EOF
    return $?
}

isInited() {
    # Check if scenario file exists
    if [ ! -f $SCENARIO_FILE_NAME ]; then
        log "ERROR: Scenario $SCENARIO_FILE_NAME not found"
        return 1
    fi

    # Check if scenario is available on remote server
    REMOTE_DIR=$SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME
    ssh $use_key -o 'StrictHostKeyChecking no' $SCENARIO_SERVER_SSHCONFIG "[ -d '${REMOTE_DIR}' ]"
    return $?
}

function printUsage() {
    log "Usage: $0 <scenario> [init,up,stop,start,down,deinit,test,updateconfig] [-v|-s|-h]"
    log
    log "        Lifecycle actions:"
    log "          init   - init remote scenario dir"
    log "          up     - Create and start scenario"
    log "          stop   - Stop scenario"
    log "          start  - Start scenario if stopped"
    log "          down   - Stop and shut down scenario"
    log "          deinit - Cleanup/remove remote and local scenario dir (leave config untouched)"
    log
    log "        Service actions:"
    log "          test   - Test the running scenario"
    log "          updateconfig - update local scenario config"
    log
    log "        Options:"
    log "          -v|--verbose - verbosee"
    log "          -s|--silent  - silent"
    log "          -h|--help    - help"
    log
    log "Example: $0 dev (defaults to: up,test)"
    log "Example: $0 dev stop,start"
    log "Example: $0 dev up"
    log "Example: $0 dev deinit"
    log
    log "* up will call init and stop"
    log "* deinit will call down"
    log
    log "Available scenarios:"
    cd $cwd && find Scenarios -name *.scenario | sed "s;Scenarios/;    ;" | sed "s/\.scenario//" | sed "s/ /\\ /g"
}

# Check for keyfile
if [[ -n "${keyfile}" ]]; then
    logVerbose "Use ${keyfile}"
    use_key="-i ${keyfile}"
fi

# Scan for scenario
if [ -z "$1" ]; then
    log "Unknown scenario"
    printUsage
    exit 1
fi
SCENARIO_NAME=$(basename $1)
SCENARIO_NAME_SPACE=$(dirname $1)
SCENARIO_FILE_NAME=$cwd/Scenarios/$SCENARIO_NAME_SPACE/$SCENARIO_NAME.scenario
SCENARIO_FILE_NAME_TMP=$SCENARIO_FILE_NAME.tmp
SCENARIOS_DIR_LOCAL=$cwd/_scenarios
shift

# Default steps
DEFAULT_STEPS="test"
if [ -z "$1" ]; then
    STEPS=$DEFAULT_STEPS
else
    STEPS=$1
fi
shift

# Parse all "-" args
for i in "$@"
do
case $i in
    -v|--verbose)
    VERBOSITY="-v"
    ;;
    -s|--silent)
    VERBOSITY="-s"
    ;;
    -h|--help)
    HELP=true
    ;;
    *)
    # unknown option
    log "Unknown option: $i"
    printUsage
    exit 1
    ;;
esac
done

# Print help
if [ -n "$HELP" ]; then
    printUsage
    exit 0
fi

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
    # Source scenario env file (tmp)
    if [ -f $SCENARIO_FILE_NAME_TMP ]; then
        source $SCENARIO_FILE_NAME_TMP
    fi

    # Source scenario env file
    if [ -f $SCENARIO_FILE_NAME ]; then
        source $SCENARIO_FILE_NAME
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
    log "Please check $SCENARIO_FILE_NAME and commit it to git."
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
        log "Available component dirs:"
        cd $cwd && find Components -name defaults.scenario.yaml | sed "s;Components/;    ;" | sed "s/.defaults.scenario.yaml//" | sed "s/ /\\ /g"
        SCENARIO_SRC_COMPONENT=$(ask_with_default "Choose available component dir  :" "")
    fi

    # Convert defaults.scenario.yaml > _defaults.scenario.sh
    SCENARIO_DEFAULTS_YAML=$cwd/Components/$SCENARIO_SRC_COMPONENT/defaults.scenario.yaml
    SCENARIO_DEFAULTS_ENV=$cwd/Components/$SCENARIO_SRC_COMPONENT/_defaults.scenario.sh
    parse_yaml $SCENARIO_DEFAULTS_YAML > $SCENARIO_DEFAULTS_ENV

    # Check $SCENARIO_FILE_NAME for missing variables
    local current_comment=""
    rm -rf $SCENARIO_FILE_NAME_TMP
    IFS=$'\n'
    for line in $(cat "$SCENARIO_DEFAULTS_ENV"); do
        if echo "$line" | grep -q "="; then
            local variable=$(echo "$line" | cut -d "=" -f 1)
            local default=$(echo "$line" | cut -d "=" -f 2 | sed "s/^\"//" | sed "s/\"$//")
            local value=${!variable}
            #log
            #log "current_comment : \"$current_comment\""
            #log "variable        : \"$variable\""
            #log "default         : \"$default\""
            #log "value           : \"$value\""
            if [ -z "$value" ]; then
                value=$(ask_with_default "$current_comment" "$default")
                #logVerbose "I ASKED AND GOT : \"$value\""
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
    UPDATES=$(diff $SCENARIO_FILE_NAME $SCENARIO_FILE_NAME_TMP)
    if [[ ! -f $SCENARIO_FILE_NAME || -n "$UPDATES" ]]; then
        echo
        echo "I found changes for some variables."
        echo "Changes:"
        echo "$UPDATES"
        SURE=$(ask_with_default "Should I update the scenario with the new values? (yes/no)?" "no")
        if [ -z `echo $SURE | grep -i y` ]; then
            log "Not updated."
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
    if isInited; then
        logVerbose "Scenario '$SCENARIO_NAME' is available on remote server. Will be updated."
        if [ "$VERBOSITY" == "-v" ]; then
            callRemote tree -L 3 -a .
        fi
    else
        log "Scenario '$SCENARIO_NAME' is not yet available on remote server."
        ssh $use_key -o 'StrictHostKeyChecking no' $SCENARIO_SERVER_SSHCONFIG bash -s << EOF
            mkdir -p $SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME
EOF
    fi
    RSYNC_VERBOSE="-q"
    if [ "$VERBOSITY" == "-v" ]; then
        RSYNC_VERBOSE="-v"
    fi
    rsync -azP $RSYNC_VERBOSE --exclude=_data --delete -e "ssh $use_key -o 'StrictHostKeyChecking no'" $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME_SPACE/$SCENARIO_NAME/ $SCENARIO_SERVER_SSHCONFIG:$SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME/
    if [ "$VERBOSITY" == "-v" ]; then
        callRemote tree -L 3 -a .
    fi
    log "Scenario '$SCENARIO_NAME' is now inited (available on remote server)."
}

function up() {
    if ! isInited; then
        log "Scenario '$SCENARIO_NAME' is not inited."
        return 1
    fi

    if callRemote ./scenario.sh test $VERBOSITY; then
        log "Scenario '$SCENARIO_NAME' is already running."
        return 1
    fi

    # Startup scenario
    banner "Startup scenario '$SCENARIO_NAME'"
    callRemote ./scenario.sh up $VERBOSITY

    log "Scenario '$SCENARIO_NAME' is now up (running on remote server)."
}

function start() {
    if ! isInited; then
        log "Scenario '$SCENARIO_NAME' is not inited."
        return 1
    fi

    if callRemote ./scenario.sh test $VERBOSITY; then
        log "Scenario '$SCENARIO_NAME' is already running."
        return 1
    fi

    # Restart once server
    banner "Restart once server"
    callRemote ./scenario.sh start $VERBOSITY

    log "Scenario '$SCENARIO_NAME' is now started (running on remote server)."
}

function stop() {
    if ! isInited; then
        log "Scenario '$SCENARIO_NAME' is not inited."
        return 1
    fi

    # Stop remotely
    banner "Stop remotely"
    callRemote ./scenario.sh stop $VERBOSITY || true

    log "Scenario '$SCENARIO_NAME' is now stopped (on remote server)."
}

function down() {
    if ! isInited; then
        log "Scenario '$SCENARIO_NAME' is not inited."
        return 1
    fi

    # Shutdown remotely
    banner "Shutdown remotely"
    callRemote ./scenario.sh down $VERBOSITY || true

    log "Scenario '$SCENARIO_NAME' is now down (server removed on remote server)."
}

function deinit() {
    if ! isInited; then
        log "Scenario '$SCENARIO_NAME' is not inited."
        return 1
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

    log "Scenario '$SCENARIO_NAME' is now deinited (removed from remote server)."
}

function test() {
    if ! isInited; then
        log "Scenario '$SCENARIO_NAME' is not inited."
        return 1
    fi

    # Test remote
    banner "Test remote"
    if isInited; then
        logVerbose "Scenario '$SCENARIO_NAME' is available on remote server."
        callRemote ./scenario.sh test $VERBOSITY
        return $?
    else
        log "Scenario '$SCENARIO_NAME' is not available on remote server."
        return 1
    fi
}

RETVAL=0
for STEP in $(echo $STEPS | sed "s/,/ /g"); do
    if [ "$STEP" == "init" ]; then
        init
        RETVAL=$? # return value
    elif [ "$STEP" == "up" ]; then
        up
        RETVAL=$? # return value
    elif [ "$STEP" == "stop" ]; then
        stop
        RETVAL=$? # return value
    elif [ "$STEP" == "start" ]; then
        start
        RETVAL=$? # return value
    elif [ "$STEP" == "down" ]; then
        down
        RETVAL=$? # return value
    elif [ "$STEP" == "deinit" ]; then
        deinit
        RETVAL=$? # return value
    elif [ "$STEP" == "test" ]; then
        test
        RETVAL=$? # return value
    elif [ "$STEP" == "updateconfig" ]; then
        updateconfig
        RETVAL=$? # return value
    else
        log "ERROR: Unknown step: $STEP"
        exit 1
    fi
    if [ $RETVAL -ne 0 ]; then
        log "ERROR: Step '$STEP' failed with return value: $RETVAL"
        exit $RETVAL
    fi
done
