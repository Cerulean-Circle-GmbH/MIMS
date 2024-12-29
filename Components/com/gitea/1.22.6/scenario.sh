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
  deploy-tools.checkAndCreateDataVolume SCENARIO_DATA_VOLUME_1 "data-volume"
  deploy-tools.checkAndCreateDataVolume SCENARIO_DATA_VOLUME_2 "db-volume"
  deploy-tools.checkAndCreateDataVolume SCENARIO_DATA_VOLUME_3 "runner-volume"
}

function up() {
  # Check network
  deploy-tools.checkAndCreateNetwork $SCENARIO_SERVER_NETWORK_NAME

  # Check data volume
  checkAndCreateDataVolume

  # Restore backup
  deploy-tools.checkAndRestoreDataVolume $SCENARIO_DATA_VOLUME_1_RESTORESOURCE $SCENARIO_DATA_VOLUME_1_PATH 1
  deploy-tools.checkAndRestoreDataVolume $SCENARIO_DATA_VOLUME_2_RESTORESOURCE $SCENARIO_DATA_VOLUME_2_PATH 1
  deploy-tools.checkAndRestoreDataVolume $SCENARIO_DATA_VOLUME_3_RESTORESOURCE $SCENARIO_DATA_VOLUME_3_PATH 1

  # Create secrets
  # deploy-tools.checkAndCreateSecret gitea_runner_registration_token.txt plain # << Will be available in 1.23.0
  deploy-tools.checkAndCreateSecret gitea_db_passwd.txt plain

  # Set correct network name for Action Runner config
  sed -i "s/<network-placeholder>/$SCENARIO_SERVER_NETWORK_NAME/" runner_config.yaml

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
    docker volume ls | grep -E "(${SCENARIO_DATA_VOLUME_1_PATH}|${SCENARIO_DATA_VOLUME_2_PATH})"
    log ""
    log "Images:"
    docker image ls | grep gitea
    log ""
    log "Containers:"
    docker ps -all | grep ${SCENARIO_NAME}_gitea_container
  fi

  # Check Gitea status
  banner "Check Gitea $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
  deploy-tools.checkContainer "Gitea (docker)" ${SCENARIO_NAME}_gitea_container
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
