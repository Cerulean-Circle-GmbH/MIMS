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
}

function up() {
  # Check data volume
  checkAndCreateDataVolume

  # Set environment
  setEnvironment

  # Create jenkins image
  banner "Create jenkins image"
  log "Building image..."
  docker pull jenkins/jenkins:2.474-jdk17
  docker build -t ${SCENARIO_NAME}_jenkins_image . > $VERBOSEPIPE

  # Check data volume
  banner "Check data volume"
  deploy-tools.checkAndCreateDataVolume ${SCENARIO_DATA_VOLUME}

  # TODO: --strip-components=1, fix in backup before
  deploy-tools.checkAndRestoreDataVolume $SCENARIO_DATA_RESTORESOURCE $SCENARIO_DATA_VOLUME 2

  # Create and run container
  banner "Create and run container"
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS up -d
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps | grep $SCENARIO_NAME
  fi

  # Add user jenkins to group docker inside container
  GROUP_ID=$(getent group docker | cut -d: -f3)
  log "Group ID: $GROUP_ID"
  docker exec -i -u root ${SCENARIO_NAME}_jenkins_container bash -s << EOF
    if [ -z "$(getent group dockerofhost)" ]; then
      echo "Create group dockerofhost"
      groupadd -g $GROUP_ID dockerofhost
      usermod -aG dockerofhost jenkins
      usermod -aG docker jenkins
      setfacl -m user:jenkins:rw /var/run/docker.sock
    else
      echo "Group dockerofhost already exists"
    fi
EOF
  log "User jenkins groups:"
  docker exec -i ${SCENARIO_NAME}_jenkins_container groups jenkins
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
    docker image ls | grep ${SCENARIO_NAME}_jenkins_image
    log "Containers:"
    docker ps -all | grep ${SCENARIO_NAME}_jenkins_container
  fi

  # Check Jenkins status
  banner "Check Jenkins $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
  deploy-tools.checkURL "Jenkins (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_HTTPPORT/jenkins/login?from=%2Fjenkins%2F
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
