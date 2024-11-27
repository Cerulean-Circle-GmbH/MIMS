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

## Simple tools without namespace

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

## Namespace deploy-tools

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

function deploy-tools.checkContainer() {
  comment=$1
  shift
  logVerbose
  logVerbose call: docker ps \| grep "$@"
  if [[ -z $(docker ps | grep "$@") ]]; then
    log "--: not running: $1 - $comment"
    return 1
  else
    log "OK: running: $1 - $comment"
    return 0
  fi
}

function deploy-tools.checkURL() {
  comment=$1
  shift
  logVerbose
  logVerbose call: curl --connect-timeout 0 -ksL -m 10 -o /dev/null -w "%{http_code}" "$@"
  # cUrl option -L follows redirects, e.g. if http code is 301
  up=$(curl --connect-timeout 0 -ksL -m 10 -o /dev/null -w "%{http_code}" "$@")
  if [[ "$up" != "200" && "$up" != "302" ]]; then
    log "--: not running (returned $up): $1 - $comment"
    curl --connect-timeout 0 -ksL -m 10 "$@"
    return 1
  else
    log "OK: running: $1 - $comment"
    return 0
  fi
}

# TODO: Is this good practice?
function deploy-tools.addToFile() {
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
function deploy-tools.downloadFile() {
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
function deploy-tools.checkAndCreateDataVolume() {
  local datavolume=$1
  local target=$2

  # set separator for handling of arrays as environment variables
  IFS=','

  # Retrieve and convert the string back to an array
  read -r -a mountpoints_array <<< "$SCENARIO_DATA_MOUNTPOINTS"
  read -r -a names_array <<< "$SCENARIO_DATA_VOLUME_NAMES"

  if [ -z $target ]; then
    # default value
    local target="service-volume"
  fi

  if [[ $datavolume == *"/"* ]]; then
    # if relative path, prepend CONFIG_DIR
    if [[ $datavolume == .* ]]; then
      local datavolume="${datavolume/#./$CONFIG_DIR}"
    fi

    log "Volume name contains a slash, so it is a path: $datavolume"
    mkdir -p $datavolume
    chmod 777 $datavolume

    # Use the function to check if the array contains the string
    if ! deploy-tools.contains mountpoints_array "$datavolume"; then
      # Appending string '$datavolume' to the array.
      mountpoints_array+=($datavolume)
      names_array+=("/notapplicable/")
    fi
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

    # Use the function to check if the array contains the string
    if ! deploy-tools.contains mountpoints_array "$target"; then
      # Appending string '$datavolume' to the array.
      mountpoints_array+=($target)
      names_array+=($datavolume)
    fi
  fi
  # Convert the arrays to strings (e.g., using IFS as separators)
  SCENARIO_DATA_MOUNTPOINTS=${mountpoints_array[*]}
  SCENARIO_DATA_VOLUME_NAMES=${names_array[*]}
  deploy-tools.addToFile $CONFIG_DIR/.env SCENARIO_DATA_MOUNTPOINTS
  deploy-tools.addToFile $CONFIG_DIR/.env SCENARIO_DATA_VOLUME_NAMES

  # Add each volume as an environment variable
  i=1
  for volume in "${mountpoints_array[@]}"; do
    j=$((i - 1))

    eval "SCENARIO_DATA_MOUNTPOINT$i=${volume}"
    eval "SCENARIO_DATA_VOLUME_NAME$i=${names_array[$j]}"
    deploy-tools.addToFile $CONFIG_DIR/.env SCENARIO_DATA_MOUNTPOINT$i
    deploy-tools.addToFile $CONFIG_DIR/.env SCENARIO_DATA_VOLUME_NAME$i

    i=$((i + 1))
  done

  # Check SCENARIO_DATA_EXTERNAL
  if [[ "$SCENARIO_DATA_EXTERNAL" != "true" && "$SCENARIO_DATA_EXTERNAL" != "false" ]]; then
    logError "SCENARIO_DATA_EXTERNAL must be true or false (but is $SCENARIO_DATA_EXTERNAL)"
    exit 1
  fi

  # set separator to default value, otherwise docker-compose command will fail
  IFS=' '
}

# Check if network name exists and create it if necessary
function deploy-tools.checkAndCreateNetwork() {
  local network=$1

  log "Checking network name: $network"
  if [[ -z $(docker network ls | grep ${network}) ]]; then
    log "Network does not exist yet: $network. Creating it."
    docker network create $network
  else
    log "Network already exists: $network"
  fi
}

# Create secrets and show them once during initialization
function deploy-tools.checkAndCreateSecret() {
  local filename=$1
  local cipher=$2

  if [ ! -d "${SCENARIO_SRC_SECRETSDIR}" ]; then
    mkdir -p "${SCENARIO_SRC_SECRETSDIR}"
  fi

  if [ ! -f "${SCENARIO_SRC_SECRETSDIR}/$filename" ]; then
    temp_password=$(openssl rand -base64 15)
    log ""
    log "********************************************************************************************"
    log "*** Your password string is: ${temp_password} - Please write it down somewhere safe! ***"
    log "********************************************************************************************"
    log ""

    if [ $cipher = "argon2" ]; then
      echo -n "${temp_password}" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4 > ${SCENARIO_SRC_SECRETSDIR}/$filename
    else
      log "Non existing cipher method selected! Cannot create secret file!"
    fi
  fi
}

function deploy-tools.recreateKeystore() {
  local certdir="$1"
  local keystoredir="$2"
  mkdir -p $keystoredir

  # Keystore
  banner "Keystore"
  if [ -f "$keystoredir/keystore.p12" ]; then
    logVerbose "Already existing keystore.p12..."
  else
    logVerbose "Creating new $keystoredir/keystore.p12..."
    if [ -n "$certdir" ] && [ "$certdir" != "none" ] && [ -f "$certdir/fullchain.pem" ] && [ -f "$certdir/privkey.pem" ]; then
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
  local restoresource=$1
  local datavolume=$2
  local stripcomponents=$3

  # If there is a restore source (!=none), download the file
  if [ "$restoresource" != "none" ]; then
    banner "Restore data backup"
    mkdir -p _data_restore
    # use shell expansion to get last part of path for $datavolume
    deploy-tools.downloadFile $restoresource _data_restore/${datavolume##*/}.tar.gz

    # Move data to volume if empty
    if [[ $datavolume == *"/"* ]]; then
      # if relative path, prepend CONFIG_DIR
      if [[ $datavolume == .* ]]; then
        local datavolume="${datavolume/#./$CONFIG_DIR}"
      fi

      # Move data to data dir if empty
      if [ "$(ls -A $datavolume)" ]; then
        logError "Data dir is not empty: $datavolume (skip restore)"
      else
        # Extract data and strip /var/jenkins_home from the tar
        log "Extracting data into directory: $datavolume"
        # use shell expansion to get last part of path for $datavolume
        tar -xzf _data_restore/${datavolume##*/}.tar.gz -C $datavolume --strip-components=$stripcomponents
      fi
    else
      files=$(docker run --rm -v $datavolume:/data alpine sh -c "ls -A /data")
      if [ -n "$files" ]; then
        logError "Data volume is not empty: $datavolume (skip restore)"
      else
        # Extract data and strip /var/jenkins_home from the tar
        log "Extracting data into volume: $datavolume"
        # use shell expansion to get last part of path for $datavolume
        docker run --rm -v $datavolume:/data -v ./_data_restore:/backup alpine sh -c "tar -xzf /backup/${datavolume##*/}.tar.gz -C /data --strip-components=$stripcomponents > /dev/null"
        docker run --rm -v $datavolume:/data -v ./_data_restore:/backup alpine sh -c "chown -R 1000:1000 /data > /dev/null"
      fi
    fi
  fi
}

function deploy-tools.up() {
  # Set environment
  deploy-tools.setEnvironment

  # Create and run container
  banner "Create and run container"
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS up -d
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps | grep $SCENARIO_NAME
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

    # set separator for handling of arrays as environment variables
    IFS=','

    # Retrieve and convert the string back to an array
    read -r -a mountpoints_array <<< "$SCENARIO_DATA_MOUNTPOINTS"

    for volume in "${mountpoints_array[@]}"; do
      # Remove data directory if it is a path
      if [[ $volume == *"/"* ]]; then
        log "Removing data directory: $volume"
        rm -rf $volume
      fi
    done

    # set separator to default value, otherwise docker-compose command will fail
    IFS=' '
  fi
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS down $CLEANUP
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps | grep $SCENARIO_NAME
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

function deploy-tools.logs() {
  # Set environment
  deploy-tools.setEnvironment

  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS logs
}

function deploy-tools.printUsage() {
  log "Usage: $0 (up,start,stop,down,logs,test)  [-v|-s|-h]"
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
        exit 1
        ;;
    esac
  done

  # Print help
  if [ "$HELP" = true ]; then
    deploy-tools.printUsage
    exit 0
  fi
}

# Function to check if an array contains a string
function deploy-tools.contains() {
  local array="$1[@]"
  local seeking=$2
  local in=1 # 1 = false, 0 = true
  for element in "${!array}"; do
    if [[ "$element" == "$seeking" ]]; then
      in=0
      break
    fi
  done
  return $in
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
