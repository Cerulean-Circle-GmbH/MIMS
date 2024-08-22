#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env
. deploy-tools.sh

function checkURL() {
  comment=$1
  shift
  logVerbose
  logVerbose call: curl -k -s -o /dev/null -w "%{http_code}" "$@"
  up=$(curl -k -s -o /dev/null -w "%{http_code}" "$@")
  if [[ "$up" != "200" && "$up" != "302" ]]; then
    log "$1 is not running (returned $up) - $comment"
    return 1
  else
    log "OK: running: $1 - $comment"
    return 0
  fi
}

# Check if data volume is a path or a volume
function checkDataVolume() {
  datavolume=$1
  if [[ $datavolume == *"/"* ]]; then
    log "Volume name contains a slash, so it is a path: $datavolume"
    mkdir -p $datavolume
    pushd $datavolume
    ls
    popd
    SCENARIO_DATA_DIR=$datavolume
    addToFile $CONFIG_DIR/.env SCENARIO_DATA_DIR
  else
    log "Volume name does not contain a slash, so it is a volume: $datavolume"
    if [[ -z $(docker volume ls | grep ${datavolume}) ]]; then
      log "Volume does not exist yet: $datavolume"
      # Create volume if ${SCENARIO_DATA_EXTERNAL} is true
      if [[ "$SCENARIO_DATA_EXTERNAL" == "true" ]]; then
        log "Creating external volume: $datavolume"
        docker volume create $datavolume
      fi
    else
      log "Volume already exists: $datavolume"
    fi
    SCENARIO_DATA_VOLUME_NAME=$datavolume
    addToFile $CONFIG_DIR/.env SCENARIO_DATA_VOLUME_NAME
  fi

  # Check SCENARIO_DATA_EXTERNAL
  if [[ "$SCENARIO_DATA_EXTERNAL" != "true" && "$SCENARIO_DATA_EXTERNAL" != "false" ]]; then
    logError "SCENARIO_DATA_EXTERNAL must be true or false"
    exit 1
  fi
}

function up() {
  # Create jenkins image
  banner "Create jenkins image"
  log "Building image..."
  docker pull jenkins/jenkins
  docker build -t ${SCENARIO_NAME}_jenkins_image . > $VERBOSEPIPE

  # Check data volume
  banner "Check data volume"
  checkDataVolume $SCENARIO_DATA_VOLUME

  # Create and run container
  banner "Create and run container"
  docker-compose -p $SCENARIO_NAME up -d
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps
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
    else
      echo "Group dockerofhost already exists"
    fi
EOF
  log "User jenkins groups:"
  docker exec -i ${SCENARIO_NAME}_jenkins_container groups jenkins
}

function start() {
  # Start container
  banner "Start container"
  docker-compose -p $SCENARIO_NAME start
}

function stop() {
  # Stop container
  banner "Stop container"
  docker-compose -p $SCENARIO_NAME stop
  docker ps | grep $SCENARIO_NAME
}

function down() {
  # Shutdown and remove containers
  banner "Shutdown and remove containers"
  docker-compose -p $SCENARIO_NAME down -v
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps
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
  # Print volumes, images, containers and files
  if [ "$VERBOSITY" = "-v" ]; then
    banner "Test"
    log "Volumes:"
    docker volume ls | grep ${SCENARIO_NAME}_jenkins_home
    log "Images:"
    docker image ls | grep ${SCENARIO_NAME}_jenkins_image
    log "Containers:"
    docker ps -all | grep ${SCENARIO_NAME}_jenkins_container
  fi

  # Check EAMD.ucp git status
  banner "Check Jenkins $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
  checkURL "Jenkins (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_HTTPPORT/jenkins
  return $? # Return the result of the last command
}

function printUsage() {
  log "Usage: $0 (up,start,stop,down,test)  [-v|-s|-h]"
  exit 1
}

# Scenario vars
if [ -z "$1" ]; then
  printUsage
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
