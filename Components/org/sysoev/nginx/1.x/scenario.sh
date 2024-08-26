#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env
. deploy-tools.sh

# Set some variables
function setEnvironment() {
  deploy-tools.setEnvironment
}

function up() {
  # Set environment
  setEnvironment

  # Check data volume
  banner "Check data volume"
  deploy-tools.checkAndCreateDataVolume $SCENARIO_DATA_VOLUME

  # Create and run container
  banner "Create and run container"
  docker-compose pull
  docker-compose -p $SCENARIO_NAME up -d
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps
  fi
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
  # Print volumes, images, containers and files
  if [ "$VERBOSITY" = "-v" ]; then
    banner "Test"
    log "Images:"
    docker image ls | grep $SCENARIO_DOCKER_IMAGENAME
    log "Containers:"
    docker ps -all | grep ${SCENARIO_NAME}_container
  fi

  # Check EAMD.ucp git status
  banner "Check nginx $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
  deploy-tools.checkContainer "NGINX (docker)" nginx_proxy_container
  return $? # Return the result of the last command
}

# Scenario vars
if [ -z "$1" ]; then
  deploy-tools.printUsage
fi

STEP=$1
shift

deploy-tools.parseArguments

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
