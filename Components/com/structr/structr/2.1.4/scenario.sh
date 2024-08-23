#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env
. ./structr/.env
. deploy-tools.sh

# Set some variables
function setEnvironment() {
  setBaseEnvironment
}

function up() {
  # Set environment
  setEnvironment

  mkdir -p structr/_data
  mkdir -p $SCENARIO_SRC_CACHEDIR
  pushd structr/_data > /dev/null

  recreateKeystore "$SCENARIO_SERVER_CERTIFICATEDIR" "$CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR"
  chown -R ${SCENARIO_STRUCTR_UID}:${SCENARIO_STRUCTR_GID} "$CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR"

  # Check data volume
  banner "Check data volume"
  checkAndCreateDataVolume $SCENARIO_DATA_VOLUME

  # If there is a restore source (!=none), download the file
  if [ "$SCENARIO_DATA_RESTORESOURCE" != "none" ]; then
    banner "Restore data backup"
    mkdir -p _data_restore
    downloadFile $SCENARIO_DATA_RESTORESOURCE _data_restore/data.tar.gz

    # Move data to volume if empty
    if [[ $SCENARIO_DATA_VOLUME == *"/"* ]]; then
      # Move data to data dir if empty
      if [ "$(ls -A $SCENARIO_DATA_VOLUME)" ]; then
        logError "Data dir is not empty: $SCENARIO_DATA_VOLUME (skip restore)"
      else
        # Extract data and strip /var/jenkins_home from the tar
        log "Extracting data into directory: $SCENARIO_DATA_VOLUME"
        tar -xzf _data_restore/data.tar.gz -C $SCENARIO_DATA_VOLUME --strip-components=1
      fi
    else
      FILES=$(docker run --rm -v $SCENARIO_DATA_VOLUME:/data alpine sh -c "ls -A /data")
      if [ -n "$FILES" ]; then
        logError "Data volume is not empty: $SCENARIO_DATA_VOLUME (skip restore)"
      else
        # Extract data and strip /var/jenkins_home from the tar
        log "Extracting data into volume: $SCENARIO_DATA_VOLUME"
        docker run --rm -v $SCENARIO_DATA_VOLUME:/data -v ./_data_restore:/backup alpine sh -c "tar -xzf /backup/data.tar.gz -C /data --strip-components=1 > /dev/null"
        docker run --rm -v $SCENARIO_DATA_VOLUME:/data -v ./_data_restore:/backup alpine sh -c "chown -R ${SCENARIO_STRUCTR_UID}:${SCENARIO_STRUCTR_GID} /data > /dev/null"
      fi
    fi
  fi

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
  recreateKeystore "$SCENARIO_SERVER_CERTIFICATEDIR" "$CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR"
  chown -R ${SCENARIO_STRUCTR_UID}:${SCENARIO_STRUCTR_GID} "$CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR"

  # Start container
  banner "Start container"
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS start
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps | grep $SCENARIO_NAME
  fi
}

function stop() {
  # Stop container
  banner "Stop container"
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS stop
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps | grep $SCENARIO_NAME
  fi
}

function down() {
  setEnvironment

  # Shutdown and remove containers
  banner "Shutdown and remove containers"
  CLEANUP=""
  if [ "$SCENARIO_DATA_EXTERNAL" == "false" ]; then
    CLEANUP="--volumes"
  fi
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS down $CLEANUP
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps | grep $SCENARIO_NAME
  fi

  # Remove data directory if it is a path and SCENARIO_DATA_EXTERNAL is false
  if [[ $SCENARIO_DATA_VOLUME == *"/"* && "$SCENARIO_DATA_EXTERNAL" == "false" ]]; then
    log "Removing data directory: $SCENARIO_DATA_VOLUME"
    rm -rf $SCENARIO_DATA_VOLUME
  fi

  # Cleanup docker
  banner "Cleanup docker volumes and images"
  docker image prune -f

  # Remove structr dir and other stuff
  rm -rf structr

  # Test
  banner "Test"
  if [ "$VERBOSITY" == "-v" ]; then
    docker volume ls | grep ${REAL_VOLUME_NAME}
    tree -L 3 -a .
  fi
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
  checkURL "structr server (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTP/structr/
  checkURL "structr server (https)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTPS/structr/
  checkURL "structr server (https) login" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTPS/structr/rest/login -XPOST -d '{ "name": "admin", "password": "*******" }'
  checkURL "structr server (https) login via reverse proxy (admin)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login -XPOST -d '{ "name": "admin", "password": "*******" }'
  checkURL "structr server (https) login via reverse proxy (NeomCityManager)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login -XPOST -d '{ "name": "NeomCityManager", "password": "secret" }'
  checkURL "structr server (https) login via reverse proxy (Visitor)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login -XPOST -d '{ "name": "Visitor", "password": "secret" }'
}

function printUsage() {
  log "Usage: $0 (up,start,stop,down,test)  [-v|-s|-h]"
  exit 1
}

# Scenario vars
if [ -z "$1" ]; then
  printUsage
  exit 1
fi

STEP=$1
shift

VERBOSEPIPE="/dev/null"

# Parse all "-" args
for i in "$@"; do
  case $i in
    -v | --verbose)
      VERBOSITY=$i
      VERBOSEPIPE="/dev/stdout"
      ;;
    -s | --silent)
      VERBOSITY=$i
      ;;
    -h | --help)
      HELP=true
      ;;
    *)
      # unknown option
      logError "Unknown option: $i"
      printUsage
      ;;
  esac
done

# Print help
if [ "$HELP" = true ]; then
  printUsage
fi

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
  printUsage
  exit 1
fi

exit $?
