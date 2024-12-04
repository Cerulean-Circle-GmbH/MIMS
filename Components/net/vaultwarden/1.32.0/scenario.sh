#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env
. deploy-tools.sh

# Set some variables
function setEnvironment() {
  deploy-tools.setEnvironment
}

function checkAndCreateDataVolume() {
  banner "Check data volume"
  deploy-tools.checkAndCreateDataVolume SCENARIO_DATA_VOLUME_1
}

function up() {
  # Check network
  deploy-tools.checkAndCreateNetwork $SCENARIO_SERVER_NETWORK_NAME

  # Check data volume
  checkAndCreateDataVolume

  # Create secret
  deploy-tools.checkAndCreateSecret vaultwarden_admin_token.txt argon2

  deploy-tools.up
}

function start() {
  # Check data volume
  checkAndCreateDataVolume

  deploy-tools.start
}

function stop() {
  # Check data volume
  checkAndCreateDataVolume

  deploy-tools.stop
}

function down() {
  # Check data volume
  checkAndCreateDataVolume

  deploy-tools.down
}

function test() {
  # Check data volume
  checkAndCreateDataVolume

  # Set environment
  setEnvironment

  # Print volumes, images, containers and files
  if [ "$VERBOSITY" = "-v" ]; then
    banner "Test"
    log "Volumes:"
    docker volume ls | grep ${SCENARIO_DATA_VOLUME_1_PATH}
    log ""
    log "Images:"
    docker image ls | grep vaultwarden
    log ""
    log "Containers:"
    docker ps -all | grep ${SCENARIO_NAME}_vaultwarden_container
  fi

  # Check Vaultwarden status
  banner "Check Vaultwarden $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
  deploy-tools.checkContainer "Vaultwarden (docker)" ${SCENARIO_NAME}_vaultwarden_container
  return $? # Return the result of the last command
}

function logs() {
  # Check data volume
  checkAndCreateDataVolume

  deploy-tools.logs
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
else
  deploy-tools.printUsage
  exit 1
fi

exit $?
