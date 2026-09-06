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

# Color definitions (disabled when NO_COLOR is set or stdout is not a terminal)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  _C_RESET=$'\033[0m'
  _C_BOLD=$'\033[1m'
  _C_RED=$'\033[0;31m'
  _C_RED_BOLD=$'\033[1;31m'
  _C_YELLOW_BOLD=$'\033[1;33m'
  _C_CYAN_BOLD=$'\033[1;36m'
  _C_WHITE_BOLD=$'\033[1;37m'
  _C_GRAY=$'\033[0;90m'
else
  _C_RESET=''; _C_BOLD=''; _C_RED=''; _C_RED_BOLD=''
  _C_YELLOW_BOLD=''; _C_CYAN_BOLD=''; _C_WHITE_BOLD=''; _C_GRAY=''
fi

# Log verbose
function logVerbose() {
  if [ "$VERBOSITY" != "-v" ]; then
    return
  fi
  echo "${_C_GRAY}$*${_C_RESET}"
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
  echo "${_C_RED_BOLD}✖  ERROR:${_C_RESET} ${_C_RED}$*${_C_RESET}" >&2
}

# Big section banner (only in verbose mode)
function bannerBig() {
  if [ "$VERBOSITY" != "-v" ]; then
    return
  fi
  local msg="$*"
  local len=${#msg}
  local line
  line=$(printf '═%.0s' $(seq 1 $((len + 4))))
  echo ""
  echo "${_C_CYAN_BOLD}  ╔${line}╗${_C_RESET}"
  echo "${_C_CYAN_BOLD}  ║${_C_RESET}  ${_C_WHITE_BOLD}${msg}${_C_RESET}  ${_C_CYAN_BOLD}║${_C_RESET}"
  echo "${_C_CYAN_BOLD}  ╚${line}╝${_C_RESET}"
  echo ""
}

# Small section banner (only in verbose mode)
function banner() {
  if [ "$VERBOSITY" != "-v" ]; then
    return
  fi
  echo ""
  echo "${_C_YELLOW_BOLD}  ▸ $1${_C_RESET}"
  echo ""
}

## Namespace deploy-tools

# Set some variables
function deploy-tools.setEnvironment() {
  # Source the .env file
  set -a # Automatically export all variables
  # 'source' isn't available on all systems, so use . instead
  . .env
  set +a

  # This separation is necessary because of the old version of docker on WODA.test
  COMPOSE_FILE_ARGUMENTS="-f docker-compose.yml -f docker-compose.volumes.yml"
  if [[ $SCENARIO_TRAEFIK_ENABLE = "true" ]]; then
    # add traefik related stuff
    COMPOSE_FILE_ARGUMENTS="${COMPOSE_FILE_ARGUMENTS} -f docker-compose.traefik.yml"
  fi
  if [[ $SCENARIO_BACKUP_ENABLE = "true" || $SCENARIO_BACKUP_1_ENABLE = "true" ]]; then
    # add backup related stuff
    COMPOSE_FILE_ARGUMENTS="${COMPOSE_FILE_ARGUMENTS} -f docker-compose.backup.yml"
  fi

  # Rsync verbosity
  RSYNC_VERBOSE="-q"
  if [ "$VERBOSITY" != "-s" ]; then
    RSYNC_VERBOSE="-v"
  fi
}

function deploy-tools.setDockerSockPermissions() {
  local sock=/var/run/docker.sock
  [ -S "$sock" ] || return 0

  local current_perms current_owner me
  me=$(whoami)
  current_perms=$(stat -c "%a" "$sock" 2>/dev/null || stat -f "%OLp" "$sock" 2>/dev/null)
  current_owner=$(stat -c "%U" "$sock" 2>/dev/null || stat -f "%Su" "$sock" 2>/dev/null)

  local current_group
  current_group=$(stat -c "%G" "$sock" 2>/dev/null || stat -f "%Sg" "$sock" 2>/dev/null)

  # Case 1: owned by current user with mode 666
  if [ "$current_perms" = "666" ] && [ "$current_owner" = "$me" ]; then
    logVerbose "docker.sock permissions already correct (owner=$current_owner, mode=$current_perms)"
    return 0
  fi

  # Case 2: owned by root:docker with mode 660 and user is in docker group
  if [ "$current_perms" = "660" ] && [ "$current_group" = "docker" ] && id -nG "$me" | grep -qw "docker"; then
    logVerbose "docker.sock accessible via docker group (owner=$current_owner:$current_group, mode=$current_perms)"
    return 0
  fi

  log "⚠️  docker.sock needs fixing (owner=$current_owner, mode=$current_perms) — expected owner=$me, mode=666"

  if sudo -n true 2>/dev/null; then
    sudo chown "$me":"$me" "$sock"
    sudo chmod 666 "$sock"
    log "✅ docker.sock permissions fixed."
  else
    logError "Cannot fix docker.sock: passwordless sudo not available. Run manually: sudo chown $me:$me $sock && sudo chmod 666 $sock"
  fi
}

function deploy-tools.checkContainer() {
  comment=$1
  shift
  logVerbose
  logVerbose call: docker ps --format '{{.Names}}' \| grep -Fx "$1"
  if ! docker ps --format '{{.Names}}' | grep -Fxq "$1"; then
    log "❌: not running: $1 - $comment"
    return 1
  else
    log "✅: running: $1 - $comment"
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
    log "❌: not running (returned $up): $1 - $comment"
    curl --connect-timeout 0 -ksL -m 10 "$@"
    return 1
  else
    log "✅: running: $1 - $comment"
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
    echo "${envvar}=\"${!envvar}\"" >> $file
    #logVerbose "Added $envvar to $file"
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
  local datavolume_var="${1}_PATH"
  local external_var="${1}_EXTERNAL"
  # resolve value by bash variable indirection
  local datavolume=${!datavolume_var}
  local external=${!external_var}
  local target=$2
  local creation_mode=$3

  # set separator for handling of arrays as environment variables
  IFS=','

  if [ -z $target ]; then
    # default value
    local target="service-volume"
  fi

  if [[ $datavolume == *"/"* ]]; then
    # if relative path, prepend CONFIG_DIR
    if [[ $datavolume == .* ]]; then
      local datavolume="${datavolume/#./$CONFIG_DIR}"
    fi

    logVerbose "Volume name contains a slash, so it is a path: $datavolume"

    # Only create directory if creation_mode is not "nocreate"
    if [[ "$creation_mode" != "nocreate" ]]; then
      mkdir -p $datavolume
      chmod 777 $datavolume
    fi

    # Use the function to check if the array contains the string
    if ! deploy-tools.contains mountpoints_array "$datavolume"; then
      # Appending string '$datavolume' to the array.
      mountpoints_array+=($datavolume)
    fi
  else
    logVerbose "Volume name does not contain a slash, so it is a volume: $datavolume"
    # Exakter Namensvergleich: 'docker volume ls | grep mcp_rag_index' trifft
    # sonst auch 'vai-mcp_rag_index', das Volume wird nicht angelegt und
    # 'docker compose up' scheitert danach an genau diesem fehlenden Volume.
    if ! docker volume ls --format '{{.Name}}' | grep -Fxq "$datavolume"; then
      logVerbose "Volume does not exist yet: $datavolume"
      # Create volume if $external is true and creation_mode is not "nocreate"
      if [[ "$external" == "true" && "$creation_mode" != "nocreate" ]]; then
        log "Creating external volume: $datavolume"
        docker volume create $datavolume
      fi
    else
      logVerbose "Volume already exists: $datavolume"
    fi

    # Use the function to check if the array contains the string
    if ! deploy-tools.contains mountpoints_array "$target"; then
      # Appending string '$datavolume' to the array.
      mountpoints_array+=($target)
    fi
  fi
  # Convert the arrays to strings (e.g., using IFS as separators)
  SCENARIO_DATA_MOUNTPOINTS=${mountpoints_array[*]}
  deploy-tools.addToFile $CONFIG_DIR/.env SCENARIO_DATA_MOUNTPOINTS

  # Add each volume as an environment variable
  i=1
  for volume in "${mountpoints_array[@]}"; do
    j=$((i - 1))

    eval "SCENARIO_DATA_MOUNTPOINT_$i=${volume}"
    deploy-tools.addToFile $CONFIG_DIR/.env SCENARIO_DATA_MOUNTPOINT_$i

    i=$((i + 1))
  done

  # Check $external
  if [[ "$external" != "true" && "$external" != "false" ]]; then
    logError "${external_var} must be true or false (but is $external)"
    exit 1
  fi

  # set separator to default value, otherwise docker-compose command will fail
  IFS=' '
}

# Check if network name exists and create it if necessary
function deploy-tools.checkAndCreateNetwork() {
  local network=$1

  logVerbose "Checking network name: $network"
  if ! docker network ls --format '{{.Name}}' | grep -Fxq "$network"; then
    log "Network does not exist yet: $network. Creating it."
    docker network create $network
  else
    logVerbose "Network already exists: $network"
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
    log "${_C_YELLOW_BOLD}  ┌─────────────────────────────────────────────────────────────────────┐${_C_RESET}"
    log "${_C_YELLOW_BOLD}  │  ⚠   Your password — write it down somewhere safe!${_C_RESET}"
    log "${_C_YELLOW_BOLD}  │${_C_RESET}  ${_C_WHITE_BOLD}${temp_password}${_C_RESET}"
    log "${_C_YELLOW_BOLD}  └─────────────────────────────────────────────────────────────────────┘${_C_RESET}"
    log ""

    if [ $cipher = "plain" ]; then
      echo -n "${temp_password}" > ${SCENARIO_SRC_SECRETSDIR}/$filename
    elif [ $cipher = "argon2" ]; then
      if ! command -v argon2 &> /dev/null; then
        logError "Command argon2 could not be found! Exiting!"
        exit 1
      fi

      echo -n "${temp_password}" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4 > ${SCENARIO_SRC_SECRETSDIR}/$filename
    else
      logError "Non existing cipher method selected! Cannot create secret file!"
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
        docker run --rm -v $datavolume:/data -v ${SCENARIO_SRC_CACHEDIR}/_data_restore:/backup alpine sh -c "tar -xzf /backup/${datavolume##*/}.tar.gz -C /data --strip-components=$stripcomponents > /dev/null"
        docker run --rm -v $datavolume:/data -v ${SCENARIO_SRC_CACHEDIR}/_data_restore:/backup alpine sh -c "chown -R 1000:1000 /data > /dev/null"
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

function deploy-tools.waitForContainer() {
  local container_name=$1
  local retries=30
  local wait_time=2

  log "Waiting for container $container_name to be ready..."
  for ((i = 0; i < retries; i++)); do
    if docker ps --format '{{.Names}}' | grep -Fxq "$container_name"; then
      log "Container $container_name is running."
      return 0
    fi
    sleep $wait_time
  done

  logError "Container $container_name did not start within the expected time."
  return 1
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
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS down

  # Count the number of environment variables starting with SCENARIO_DATA_VOLUME_ and ending with _PATH
  count=$(env | grep -E "^SCENARIO_DATA_VOLUME_[0-9]+_PATH=" | wc -l)
  for ((i = 1; i <= $count; i++)); do
    local datavolume_var="SCENARIO_DATA_VOLUME_${i}_PATH"
    local external_var="SCENARIO_DATA_VOLUME_${i}_EXTERNAL"
    # resolve value by bash variable indirection
    local datavolume=${!datavolume_var}
    local external=${!external_var}

    if [ "$external" == "false" ]; then
      # Remove data directory if it is a path
      if [[ $datavolume == *"/"* ]]; then
        log "Removing data directory: $datavolume"
        rm -rf $datavolume
      else
        # otherwise remove docker volume
        log "Removing docker volume:"
        docker volume rm -f $datavolume
      fi
    fi
  done

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

  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS logs -f
}

function deploy-tools.backupVolume() {
  local datavolume_var=$1
  local target=$2
  local scenario_name=$3
  local timestamp=$4
  local backupdir=$5

  # resolve value by bash variable indirection
  local datavolume=${!datavolume_var}

  # Create backup directory if it does not exist
  mkdir -p "$backupdir"

  # Backup the volume into a tar.gz file
  target_file="${scenario_name}_${timestamp}_${target}.tar.gz"
  log "Backing up volume '${datavolume}' to ${backupdir}/${target_file}"
  docker run --rm -v ${datavolume}:/data ubuntu du -skh /data
  #docker run --rm -v ${datavolume}:/data -v ${backupdir}:/backup ubuntu tar czf /backup/${target_file} -C /data .
  docker run --rm -v ${datavolume}:/data -v ${backupdir}:/backup ubuntu bash -c "echo 'tar it';tar czf /backup/${target_file} -C /data .;echo '${target_file} tared'"
  ls -lah ${backupdir}/${target_file}
}

function deploy-tools.restoreVolume() {
  local datavolume_var=$1
  local source=$2
  local scenario_name=$3
  local timestamp=$4
  local backupdir=$5

  # resolve value by bash variable indirection
  local datavolume=${!datavolume_var}

  # Backup the volume into a tar.gz file
  source_file="${scenario_name}_${timestamp}_${source}.tar.gz"
  log "Restoring volume '${datavolume}' from ${backupdir}/${source_file}"
  if [ ! -f "${backupdir}/${source_file}" ]; then
    logError "Backup file ${backupdir}/${source_file} does not exist!"
    exit 1
  fi
  # Clean up the data volume before restoring
  docker run --rm -v ${datavolume}:/data alpine sh -c "rm -rf /data/* /data/.[!.]* /data/..?*"
  # Restoring
  docker run --rm -v ${datavolume}:/data -v ${backupdir}:/backup ubuntu sh -c "tar xzf /backup/${source_file} -C /data"
}

function deploy-tools.printUsage() {
  log "Usage: $0 (up,start,stop,down,logs,test,backup,restore,update)  [-v|-s|-h]"
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
