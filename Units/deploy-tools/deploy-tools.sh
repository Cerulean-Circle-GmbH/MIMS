#!/usr/bin/env bash

# TODO: Define which variables are expected of give then as arguments

# Get config dir
pushd $(dirname $0) > /dev/null
CONFIG_DIR=$(pwd)
popd > /dev/null

# Check docker-compose command
if docker compose version > /dev/null 2>&1; then
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

# Log error
function logError() {
  echo "ERROR: $@" > /dev/stderr
}

# Banner
function bannerBig() {
  logVerbose
  logVerbose "####################################################################################################"
  logVerbose "## $@"
  logVerbose "####################################################################################################"
  logVerbose
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

# TODO: Is this good practice?
function addToFile() {
  local file=$1
  local envvar=$2
  if [ -f "$file" ]; then
    cat $file | grep -v "$envvar" > $file.tmp
    cat $file.tmp > $file
    rm $file.tmp
    # Add envvar to file with using $envvar as variable
    echo "${envvar}=${!envvar}" >> $file
    logVerbose "Added $envvar to $file"
  fi
}
