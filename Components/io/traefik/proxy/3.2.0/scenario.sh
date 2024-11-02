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
  deploy-tools.checkAndCreateDataVolume ${SCENARIO_DATA_VOLUME}

  # create traefik config files
  # mkdir -p ${SCENARIO_DATA_VOLUME}/configs
  # touch ${SCENARIO_DATA_VOLUME}/configs/tls.yml
  # touch ${SCENARIO_DATA_VOLUME}/configs/traefik.yml
  # touch ${SCENARIO_DATA_VOLUME}/acme_letsencrypt.json
  # sudo chown root:root ${SCENARIO_DATA_VOLUME}/acme_letsencrypt.json
  # sudo chmod 600 ${SCENARIO_DATA_VOLUME}/acme_letsencrypt.json
}

function up() {
  # Check data volume
  checkAndCreateDataVolume

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
    docker volume ls | grep ${SCENARIO_DATA_VOLUME}
    log "Images:"
    docker image ls | grep traefik
    log "Containers:"
    docker ps -all | grep ${SCENARIO_NAME}_traefik_container
  fi

  # Check Traefik Proxy status
  banner "Check Traefik Proxy $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
  deploy-tools.checkContainer "Traefik Proxy (docker)" ${SCENARIO_NAME}_traefik_container
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
