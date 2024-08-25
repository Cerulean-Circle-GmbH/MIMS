#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env
. ./structr/.env
. deploy-tools.sh

# Set some variables
function setEnvironment() {
  deploy-tools.setEnvironment
}

# TODO: Add backup step to all scenarios

function up() {
  # Set environment
  setEnvironment

  mkdir -p structr/_data
  mkdir -p $SCENARIO_SRC_CACHEDIR
  pushd structr/_data > /dev/null

  # If none
  if [ "$SCENARIO_SERVER_CERTIFICATEDIR" != "none" ]; then
    recreateKeystore "$SCENARIO_SERVER_CERTIFICATEDIR" "$CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR"
  else
    # TODO: Create a keystore if it does not exist and remove it from git
    mkdir -p $CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR/
    cp -f $CONFIG_DIR/structr/keystore.p12 $CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR/
  fi

  # Check data volume
  banner "Check data volume"
  checkAndCreateDataVolume $SCENARIO_DATA_VOLUME

  # TODO: --strip-components=1, fix in backup before
  deploy-tools.checkAndRestoreDataVolume $SCENARIO_DATA_RESTORESOURCE $SCENARIO_DATA_VOLUME 1

  # Download structr.zip
  banner "Download structr.zip"
  downloadFile https://test.wo-da.de/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip structr.zip
  popd > /dev/null

  # Create structr image
  banner "Create structr image"
  log "Building image..."
  # Only pull if image contains a "/" (means it's a repository)
  if [[ $SCENARIO_STRUCTR_IMAGE == *"/"* ]]; then
    docker pull ${SCENARIO_STRUCTR_IMAGE}
  fi
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS build > $VERBOSEPIPE
  docker image ls | grep $SCENARIO_STRUCTR_IMAGE > $VERBOSEPIPE

  # Check netwrok ${SCENARIO_SERVER_NETWORKNAME}
  banner "Check network ${SCENARIO_SERVER_NETWORKNAME}"
  if [[ -z $(docker network ls | grep ${SCENARIO_SERVER_NETWORKNAME}) ]]; then
    log "Creating network ${SCENARIO_SERVER_NETWORKNAME}"
    docker network create ${SCENARIO_SERVER_NETWORKNAME}
  fi

  # Create and run container
  banner "Create and run container"
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS up -d
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps
  fi
}

function start() {
  # Set environment
  setEnvironment

  if [ "$SCENARIO_SERVER_CERTIFICATEDIR" != "none" ]; then
    recreateKeystore "$SCENARIO_SERVER_CERTIFICATEDIR" "$CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR"
  else
    # TODO: Create a keystore if it does not exist and remove it from git
    mkdir -p $CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR/
    cp -f $CONFIG_DIR/structr/keystore.p12 $CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR/
  fi

  deploy-tools.start
}

function stop() {
  deploy-tools.stop
}

function down() {
  deploy-tools.down

  # Remove structr dir and other stuff
  rm -rf structr
}

function test() {
  setEnvironment

  # Test
  # Print volumes, images, containers and files
  if [ "$VERBOSITY" == "-v" ]; then
    banner "Test"
    log "Volumes:"
    docker volume ls | grep ${SCENARIO_DATA_VOLUME}
    log "Images:"
    docker image ls | grep ${SCENARIO_STRUCTR_IMAGE}
    log "Containers:"
    docker ps | grep ${SCENARIO_STRUCTR_CONTAINER}
  fi

  # Check running servers
  banner "Check running servers"
  checkURL "structr server (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_HTTP/structr/
  checkURL "structr server (https)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_HTTPS/structr/
  checkURL "structr server (https) login" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_HTTPS/structr/rest/login -XPOST -d '{ "name": "admin", "password": "*******" }'
  #checkURL "structr server (https) login via reverse proxy (admin)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login -XPOST -d '{ "name": "admin", "password": "*******" }'
  #checkURL "structr server (https) login via reverse proxy (NeomCityManager)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login -XPOST -d '{ "name": "NeomCityManager", "password": "secret" }'
  #checkURL "structr server (https) login via reverse proxy (Visitor)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login -XPOST -d '{ "name": "Visitor", "password": "secret" }'
}

# Scenario vars
if [ -z "$1" ]; then
  deploy-tools.printUsage
  exit 1
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
