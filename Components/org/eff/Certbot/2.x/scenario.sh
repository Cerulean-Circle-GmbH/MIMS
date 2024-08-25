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
  # Set environment
  setEnvironment

  # Shutdown and remove containers
  banner "Shutdown and remove containers"
  docker-compose -p $SCENARIO_NAME down
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps
  fi

  # Cleanup docker
  banner "Cleanup docker"
  docker image prune -f

  # Test
  banner "Test"
  if [ "$VERBOSITY" == "-v" ]; then
    tree -L 3 -a .
  fi
}

function test() {
  # Set environment
  setEnvironment

  # Print volumes, images, containers and files
  if [ "$VERBOSITY" = "-v" ]; then
    banner "Test"
    log "Images:"
    docker image ls | grep $SCENARIO_DOCKER_IMAGENAME
    log "Containers:"
    docker ps -all | grep ${SCENARIO_NAME}_container
  fi

  # Check EAMD.ucp git status
  banner "Check Certbot $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
  deploy-tools.checkContainer "Certbot (docker)" certbot_container
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
