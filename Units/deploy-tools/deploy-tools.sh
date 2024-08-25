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

# Set some variables
function setBaseEnvironment() {
  # This separation is necessary because of the old version of docker on WODA.test
  if [[ $SCENARIO_DATA_VOLUME == *"/"* ]]; then
    # SCENARIO_DATA_VOLUME is a path
    COMPOSE_FILE_ARGUMENTS="-f docker-compose.yml"
  else
    # SCENARIO_DATA_VOLUME is a volume
    COMPOSE_FILE_ARGUMENTS="-f docker-compose.yml -f docker-compose.volumes.yml"
  fi

  # Rsync verbosity
  RSYNC_VERBOSE="-q"
  if [ "$VERBOSITY" != "-s" ]; then
    RSYNC_VERBOSE="-v"
  fi
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

# Download file
function downloadFile() {
  url=$1
  file=$2
  dirs=$(dirname $file)

  # Create leading directories
  if [[ $dirs != "." && $dirs != "/" ]]; then
    mkdir -p $dirs
  fi

  # Download into cache dir
  mkdir -p ${SCENARIO_SRC_CACHEDIR}
  pushd ${SCENARIO_SRC_CACHEDIR} > /dev/null

  # Create leading directories
  if [[ $dirs != "." && $dirs != "/" ]]; then
    mkdir -p $dirs
  fi

  # If it is a URL use curl
  if [[ $url == "http"* ]]; then
    if [ ! -f "${file}" ]; then
      logVerbose "Downloading $url to $file..."
      curl -s -o "${file}.TEMP" "$url"
      # if no error, rename file
      if [ $? -eq 0 ]; then
        mv "${file}.TEMP" "${file}"
      fi
    else
      logVerbose "File $file already cached"
    fi
  else
    logVerbose "Downloading $url to $file..."
    rsync -azP $RSYNC_VERBOSE -L -e "ssh -o StrictHostKeyChecking=no" "$url" "${file}"
  fi
  popd > /dev/null

  rsync -aP $RSYNC_VERBOSE -L -e "ssh -o StrictHostKeyChecking=no" "${SCENARIO_SRC_CACHEDIR}/${file}" "${file}" > /dev/null
  logVerbose "Downloaded $url to ${SCENARIO_SRC_CACHEDIR}/$file"
}

# Check if data volume is a path or a volume
function checkAndCreateDataVolume() {
  datavolume=$1
  if [[ $datavolume == *"/"* ]]; then
    log "Volume name contains a slash, so it is a path: $datavolume"
    mkdir -p $datavolume
    chmod 777 $datavolume
    SCENARIO_DATA_MOUNTPOINT=$datavolume
    SCENARIO_DATA_VOLUME_NAME="/notapplicable/"
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
    SCENARIO_DATA_MOUNTPOINT="service-volume"
    SCENARIO_DATA_VOLUME_NAME=$datavolume
  fi
  addToFile $CONFIG_DIR/.env SCENARIO_DATA_MOUNTPOINT
  addToFile $CONFIG_DIR/.env SCENARIO_DATA_VOLUME_NAME

  # Check SCENARIO_DATA_EXTERNAL
  if [[ "$SCENARIO_DATA_EXTERNAL" != "true" && "$SCENARIO_DATA_EXTERNAL" != "false" ]]; then
    logError "SCENARIO_DATA_EXTERNAL must be true or false (but is $SCENARIO_DATA_EXTERNAL)"
    exit 1
  fi
}

function recreateKeystore() {
  local certdir="$1"
  local keystoredir="$2"
  mkdir -p $keystoredir

  # Keystore
  banner "Keystore"
  if [ -f "$keystoredir/keystore.p12" ]; then
    logVerbose "Already existing keystore.p12..."
  else
    logVerbose "Creating new $keystoredir/keystore.p12..."
    if [ -n "$certdir" ] && [ "$certdir"!="none" ] && [ -f "$certdir/fullchain.pem" ] && [ -f "$certdir/privkey.pem" ]; then
      log "Using certificates from $certdir"
      openssl x509 -noout -fingerprint -sha256 -inform pem -in "$certdir/fullchain.pem" > $VERBOSEPIPE
      openssl x509 -noout -fingerprint -sha1 -inform pem -in "$certdir/fullchain.pem" > $VERBOSEPIPE
      openssl x509 -noout -text -inform pem -in "$certdir/fullchain.pem" > $VERBOSEPIPE

      openssl pkcs12 -export -out "$keystoredir/keystore.p12" -in "$certdir/fullchain.pem" -inkey "$certdir/privkey.pem" -password pass:qazwsx#123 > $VERBOSEPIPE
    else
      logError "No certificates found!"
      logVerbose "$keystoredir/keystore.p12 not created!"
    fi
  fi
}

function createArgonHash() {
  local pass="$1"

  if ! command -v argon2 &> /dev/null; then
    echo "Command argon2 could not be found!"
    exit 1
  fi

  # Generate the ADMIN_TOKEN
  echo $(echo -n "$pass" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4)
  exit 0
}
