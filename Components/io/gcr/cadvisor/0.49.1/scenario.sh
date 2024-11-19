#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env
. deploy-tools.sh

# Set some variables
function setEnvironment() {
  deploy-tools.setEnvironment
}

function up() {
  # Check network
  deploy-tools.checkAndCreateNetwork $SCENARIO_SERVER_NETWORKNAME

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

  # Print volumes, images, containers and files
  if [ "$VERBOSITY" = "-v" ]; then
    banner "Test"
    log "Images:"
    docker image ls | grep ${SCENARIO_NAME}
    log "Containers:"
    docker ps -all | grep ${SCENARIO_NAME}_cadvisor_container
  fi

  # Check cAdvisor status
  banner "Check cAdvisor $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
  deploy-tools.checkContainer "cAdvisor (docker)" ${SCENARIO_NAME}_cadvisor_container
  deploy-tools.checkURL "cAdvisor (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_HTTPPORT/containers/
  return $? # Return the result of the last command
}

function logs() {
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
