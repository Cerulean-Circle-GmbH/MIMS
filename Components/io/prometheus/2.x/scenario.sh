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
  deploy-tools.checkAndCreateDataVolume $SCENARIO_DATA_VOLUME "data-volume"
  deploy-tools.checkAndCreateDataVolume $SCENARIO_DATA_VOLUME1 "db-volume"
}

function up() {
  # Check data volume
  checkAndCreateDataVolume

  # Set environment
  setEnvironment

  # TODO: --strip-components=1, fix in backup before
  deploy-tools.checkAndRestoreDataVolume $SCENARIO_DATA_RESTORESOURCE $SCENARIO_DATA_VOLUME 2

  # Create and run container
  banner "Create and run container"
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS up -d
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps | grep $SCENARIO_NAME
  fi
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
    docker volume ls | grep ${SCENARIO_DATA_VOLUME}
    log "Images:"
    docker image ls | grep ${SCENARIO_NAME}
    log "Containers:"
    docker ps -all | grep ${SCENARIO_NAME}_prometheus_container
  fi

  # Check Prometheus status
  banner "Check Prometheus $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
  deploy-tools.checkContainer "Prometheus (docker)" ${SCENARIO_NAME}_prometheus_container
  deploy-tools.checkURL "Prometheus (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_HTTPPORT/prometheus
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
