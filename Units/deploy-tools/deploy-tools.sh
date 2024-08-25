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
function deploy-tools.setEnvironment() {
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

function deploy-tools.checkAndRestoreDataVolume() {
  restoresource=$1
  datavolume=$2
  stripcomments=$3

  # If there is a restore source (!=none), download the file
  if [ "$restoresource" != "none" ]; then
    banner "Restore data backup"
    mkdir -p _data_restore
    downloadFile $restoresource _data_restore/data.tar.gz

    # Move data to volume if empty
    if [[ $datavolume == *"/"* ]]; then
      # Move data to data dir if empty
      if [ "$(ls -A $datavolume)" ]; then
        logError "Data dir is not empty: $datavolume (skip restore)"
      else
        # Extract data and strip /var/jenkins_home from the tar
        log "Extracting data into directory: $datavolume"
        tar -xzf _data_restore/data.tar.gz -C $datavolume --strip-components=$stripcomments
      fi
    else
      files=$(docker run --rm -v $datavolume:/data alpine sh -c "ls -A /data")
      if [ -n "$files" ]; then
        logError "Data volume is not empty: $datavolume (skip restore)"
      else
        # Extract data and strip /var/jenkins_home from the tar
        log "Extracting data into volume: $datavolume"
        docker run --rm -v $datavolume:/data -v ./_data_restore:/backup alpine sh -c "tar -xzf /backup/data.tar.gz -C /data --strip-components=$stripcomments > /dev/null"
        docker run --rm -v $datavolume:/data -v ./_data_restore:/backup alpine sh -c "chown -R 1000:1000 /data > /dev/null"
      fi
    fi
  fi
}

function deploy-tools.start() {
  # Set environment
  deploy-tools.setEnvironment

  # Start container
  banner "Start container"
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS start
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps | grep $SCENARIO_NAME
  fi
}

function deploy-tools.stop() {
  # Set environment
  deploy-tools.setEnvironment

  # Stop container
  banner "Stop container"
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS stop
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps | grep $SCENARIO_NAME
  fi
}

function deploy-tools.down() {
  # Set environment
  deploy-tools.setEnvironment

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

function deploy-tools.printUsage() {
  log "Usage: $0 (up,start,stop,down,test)  [-v|-s|-h]"
  exit 1
}

function deploy-tools.parseArguments() {
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
        deploy-tools.printUsage
        ;;
    esac
  done

  # Print help
  if [ "$HELP" = true ]; then
    deploy-tools.printUsage
  fi
}
