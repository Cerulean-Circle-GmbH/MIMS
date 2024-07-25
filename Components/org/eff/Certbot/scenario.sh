#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env

# Check docker-compose command
if [ ! -x "$(command -v docker-compose)" ]; then
  # Switch from "docker-compose" to "docker compose"
  shopt -s expand_aliases # enables expanding aliases for current script
  alias docker-compose='docker compose'
fi

# Log verbose
function logVerbose() {
  # Check for verbosity not equal to -v
  if [ "$VERBOSITY" != "-v" ]; then
    return
  fi
  echo "$@"
}

# Log
function log() {
  if [ "$VERBOSITY" == "-s" ]; then
    return
  fi
  echo "$@"
}

# Banner
function banner() {
  logVerbose
  logVerbose "--- $1"
  logVerbose
}

function checkContainer() {
  comment=$1
  shift
  logVerbose
  logVerbose call: docker ps \| grep "$@"
  if [[ -z $(docker ps | grep "$@") ]]; then
    log "$1 is not running - $comment"
    return 1
  else
    log "OK: running: $1 - $comment"
    return 0
  fi
}

function up() {
  # Create and run container
  banner "Create and run container"
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
  banner "Check Certbot $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
  checkContainer "Certbot (docker)" certbot_container
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
