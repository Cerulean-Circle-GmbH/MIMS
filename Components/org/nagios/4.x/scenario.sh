#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env
. deploy-tools.sh

# Set some variables
function setEnvironment() {
  # This separation is necessary because of the old version of docker on WODA.test
  if [[ $SCENARIO_DATA_VOLUME == *"/"* ]]; then
    # SCENARIO_DATA_VOLUME is a path
    COMPOSE_FILE_ARGUMENTS="-f docker-compose.yml -f docker-compose.path.yml"
  else
    # SCENARIO_DATA_VOLUME is a volume
    COMPOSE_FILE_ARGUMENTS="-f docker-compose.yml -f docker-compose.volumes.yml"
  fi

  # Rsync verbosity
  RSYNC_VERBOSE="-q"
  if [ "$VERBOSITY" != "-s" ]; then
    RSYNC_VERBOSE="-v"
  fi
}

function up() {
  deploy-tools.up
}

function start() {
  deploy-tools.start
}

function stop() {
  deploy-tools.stop
}

function down() {
  deploy-tools.down
}

function test() {
  # Set environment
  setEnvironment

  # Check data volume
  banner "Check data volume"
  deploy-tools.checkAndCreateDataVolume ${SCENARIO_DATA_VOLUME}

  # Print volumes, images, containers and files
  if [ "$VERBOSITY" = "-v" ]; then
    banner "Test"
    log "Volumes:"
    docker volume ls | grep ${SCENARIO_DATA_VOLUME}
    log "Images:"
    docker image ls | grep ${SCENARIO_NAME}
    log "Containers:"
    docker ps -all | grep ${SCENARIO_NAME}_nagios_container
  fi

  # Check nagios status
  banner "Check nagios $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
  deploy-tools.checkContainer "Nagios (docker)" ${SCENARIO_NAME}_nagios_container
  return $? # Return the result of the last command
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
else
  deploy-tools.printUsage
  exit 1
fi

exit $?
