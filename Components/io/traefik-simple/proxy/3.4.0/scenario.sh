#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env
. deploy-tools.sh

# Set some variables
function setEnvironment() {
  deploy-tools.setEnvironment
}

function checkAndCreateDataVolume() {
  local creation_mode=$1
  banner "Check data volume"
  deploy-tools.checkAndCreateDataVolume SCENARIO_DATA_VOLUME_1 "data" "$creation_mode"
}

function up() {
  # Check data volume
  checkAndCreateDataVolume

  # Check network "traefik"
  NETWORK_NAME="traefik"
  if [[ -z $(docker network ls | grep "$NETWORK_NAME") ]]; then
    log "Creating network: $NETWORK_NAME"
    docker network create $NETWORK_NAME
  else
    logVerbose "Network already exists: $NETWORK_NAME"
  fi

  # Set environment
  setEnvironment

  # Replace __SCENARIO_LETSENCRYPT_EMAIL__ in traefik.yml with $SCENARIO_LETSENCRYPT_EMAIL
  if [ -f "traefik.yml" ]; then
    sed -i "s/__SCENARIO_LETSENCRYPT_EMAIL__/$SCENARIO_LETSENCRYPT_EMAIL/g" traefik.yml
  fi

  # TODO: --strip-components=1, fix in backup before
  deploy-tools.checkAndRestoreDataVolume $SCENARIO_DATA_VOLUME_1_RESTORESOURCE $SCENARIO_DATA_VOLUME_1_PATH 2

  # ensure acme.json is created
#  if [[ $SCENARIO_DATA_VOLUME_1_PATH == *"/"* ]]; then
#    touch $SCENARIO_DATA_VOLUME_1_PATH/acme.json
#    chmod 600 $SCENARIO_DATA_VOLUME_1_PATH/acme.json
#  else
#    touch $SCENARIO_DATA_VOLUME_1_PATH
#  fi

  # Create and run container
  deploy-tools.up
}

function start() {
  # Check data volume
  checkAndCreateDataVolume

  deploy-tools.start
}

function stop() {
  # Check data volume
  checkAndCreateDataVolume "nocreate"

  deploy-tools.stop
}

function down() {
  # Check data volume
  checkAndCreateDataVolume "nocreate"

  deploy-tools.down
}

function test() {
  # Check data volume
  checkAndCreateDataVolume "nocreate"

  # Set environment
  setEnvironment

  # Print volumes, images, containers and files
  if [ "$VERBOSITY" = "-v" ]; then
    banner "Test"
    log "Volumes:"
    docker volume ls | grep ${SCENARIO_DATA_VOLUME_1_PATH}
    log ""
    log "Containers:"
    docker ps -all | grep ${SCENARIO_NAME}_traefik_container
  fi

  return $? # Return the result of the last command
}

function logs() {
  # Check data volume
  checkAndCreateDataVolume "nocreate"

  deploy-tools.logs
}

function backup() {
  # Check data volume (also sets the necessary environment variables)
  checkAndCreateDataVolume

  # Set environment
  setEnvironment

  banner "Backup volumes"
  TIMESTAMP=$(date +%Y%m%d%H%M%S)
  deploy-tools.backupVolume SCENARIO_DATA_VOLUME_1_PATH "data" $SCENARIO_NAME $TIMESTAMP "$SCENARIO_DATA_BACKUPDIR"
}

function restore() {
  # Check data volume (also sets the necessary environment variables)
  checkAndCreateDataVolume

  # Set environment
  setEnvironment

  banner "Restore volumes"

  # Show available timestamps from example: $SCENARIO_DATA_BACKUPDIR/$SCENARIO_NAME_$TIMESTAMP_env.tar.gz
  echo "Available backups in $SCENARIO_DATA_BACKUPDIR:"
  ls -1 $SCENARIO_DATA_BACKUPDIR | grep "$SCENARIO_NAME" | grep data | sed "s;${SCENARIO_NAME}_;;" | sed "s;_data.*;;" | sort -u

  if [ -t 0 ]; then
    read -p "Please provide a timestamp to restore from (format: YYYYMMDDHHMMSS) : " TIMESTAMP
    if [ -z "$TIMESTAMP" ]; then
      echo "Error: No timestamp provided."
      exit 1
    fi
  else
    echo "Error: Cannot prompt for input, not running in an interactive shell."
    exit 1
  fi

  deploy-tools.restoreVolume SCENARIO_DATA_VOLUME_1_PATH "data" $SCENARIO_NAME $TIMESTAMP "$SCENARIO_DATA_BACKUPDIR"
}

# Scenario vars
if [ -z "$1" ]; then
  deploy-tools.printUsage
  exit 1
fi

STEP=$1
shift

deploy-tools.parseArguments $@

if [ $STEP = "up" ]; then
  up
elif [ $STEP = "start" ]; then
  start
elif [ $STEP = "stop" ]; then
  stop
elif [ $STEP = "down" ]; then
  down
elif [ $STEP = "test" ]; then
  test
elif [ $STEP = "logs" ]; then
  logs
elif [ $STEP = "backup" ]; then
  backup
elif [ $STEP = "restore" ]; then
  restore
else
  deploy-tools.printUsage
  exit 1
fi

exit $?
