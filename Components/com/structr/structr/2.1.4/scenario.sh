#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env
. ./structr/.env
. deploy-tools.sh

# Set some variables
function setEnvironment() {
  deploy-tools.setEnvironment
}

function checkAndCreateDataVolume() {
  banner "Check data volume"
  deploy-tools.checkAndCreateDataVolume ${SCENARIO_DATA_VOLUME}
}

# TODO: Add backup step to all scenarios

function up() {
  # Check network
  deploy-tools.checkAndCreateNetwork $SCENARIO_SERVER_NETWORKNAME

  # Check data volume
  checkAndCreateDataVolume

  # Set environment
  setEnvironment

  mkdir -p structr/_data
  pushd structr/_data > /dev/null

  # If no certificate
  if [ "$SCENARIO_SERVER_CERTIFICATEDIR" != "none" ]; then
    deploy-tools.recreateKeystore "$SCENARIO_SERVER_CERTIFICATEDIR" "$CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR"
  else
    # TODO: Create a keystore if it does not exist and remove it from git
    mkdir -p $CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR/
    cp -f $CONFIG_DIR/structr/keystore.p12 $CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR/
  fi

  deploy-tools.checkAndRestoreDataVolume $SCENARIO_DATA_RESTORESOURCE $SCENARIO_DATA_VOLUME 1

  # Download structr.zip
  banner "Download structr.zip"
  deploy-tools.downloadFile https://test.wo-da.de/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip structr.zip
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

  # Create and run container
  banner "Create and run container"
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS up -d
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps
  fi
}

function start() {
  # Check data volume
  checkAndCreateDataVolume

  # Set environment
  setEnvironment

  # If no certificate
  if [ "$SCENARIO_SERVER_CERTIFICATEDIR" != "none" ]; then
    deploy-tools.recreateKeystore "$SCENARIO_SERVER_CERTIFICATEDIR" "$CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR"
  else
    # TODO: Create a keystore if it does not exist and remove it from git
    mkdir -p $CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR/
    cp -f $CONFIG_DIR/structr/keystore.p12 $CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR/
  fi

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

  # Remove structr data dir
  rm -rf structr/_data
}

function test() {
  # Check data volume
  checkAndCreateDataVolume

  # Set environment
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
  deploy-tools.checkURL "structr server (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_HTTP/structr/
  deploy-tools.checkURL "structr server (https)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_HTTPS/structr/
  deploy-tools.checkURL "structr server (https) login" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_HTTPS/structr/rest/login -XPOST -d '{ "name": "admin", "password": "*******" }'
  #deploy-tools.checkURL "structr server (https) login via reverse proxy (admin)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login -XPOST -d '{ "name": "admin", "password": "*******" }'
  #deploy-tools.checkURL "structr server (https) login via reverse proxy (NeomCityManager)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login -XPOST -d '{ "name": "NeomCityManager", "password": "secret" }'
  #deploy-tools.checkURL "structr server (https) login via reverse proxy (Visitor)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login -XPOST -d '{ "name": "Visitor", "password": "secret" }'
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
