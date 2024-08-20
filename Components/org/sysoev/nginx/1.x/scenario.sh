#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env
. deploy-tools.sh

function up() {
  # Create and run container
  banner "Create and run container"
  docker-compose pull
  docker-compose -p $SCENARIO_NAME up -d
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps
  fi
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
  checkContainer "NGINX (docker)" nginx_proxy_container
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
      log "Unknown option: $i"
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
