#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env
. deploy-tools.sh

# Set some variables
function setEnvironment() {
  setBaseEnvironment
}

function up() {
  # Set environment
  setEnvironment

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
        # Extract data and strip /var/vaultwarden_home from the tar
        log "Extracting data into directory: $SCENARIO_DATA_VOLUME"
        # TODO: --strip-components=1, fix in backup before
        tar -xzf _data_restore/data.tar.gz -C $SCENARIO_DATA_VOLUME --strip-components=2
      fi
    else
      FILES=$(docker run --rm -v $SCENARIO_DATA_VOLUME:/data alpine sh -c "ls -A /data")
      if [ -n "$FILES" ]; then
        logError "Data volume is not empty: $SCENARIO_DATA_VOLUME (skip restore)"
      else
        # Extract data and strip /var/vaultwarden_home from the tar
        log "Extracting data into volume: $SCENARIO_DATA_VOLUME"
        docker run --rm -v $SCENARIO_DATA_VOLUME:/data -v ./_data_restore:/backup alpine sh -c "tar -xzf /backup/data.tar.gz -C /data --strip-components=2 > /dev/null"
        docker run --rm -v $SCENARIO_DATA_VOLUME:/data -v ./_data_restore:/backup alpine sh -c "chown -R 1000:1000 /data > /dev/null"
      fi
    fi
  fi

  # Create and run container
  banner "Create and run container"
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS up -d
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps | grep $SCENARIO_NAME
  fi
}

function start() {
  # Set environment
  setEnvironment

  # Start container
  banner "Start container"
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS start
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps | grep $SCENARIO_NAME
  fi
}

function stop() {
  # Set environment
  setEnvironment

  # Stop container
  banner "Stop container"
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS stop
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps | grep $SCENARIO_NAME
  fi
}

function down() {
  # Set environment
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
    log "Volumes:"
    docker volume ls | grep ${SCENARIO_DATA_VOLUME}
    log "Images:"
    docker image ls | grep ${SCENARIO_NAME}
    log "Containers:"
    docker ps -all | grep ${SCENARIO_NAME}_vaultwarden_container
  fi

  # Check EAMD.ucp git status
  banner "Check Vaultwarden $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
  checkURL "Vaultwarden (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_HTTPPORT/vaultwarden
  return $? # Return the result of the last command
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
