#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env
CONFIG_DIR=$(pwd)

# Check docker-compose command
if docker compose version; then
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

# TODO: error() mit stderr

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

function checkURL() {
  comment=$1
  shift
  logVerbose
  logVerbose call: curl -k -s -o /dev/null -w "%{http_code}" "$@"
  up=$(curl -k -s -o /dev/null -w "%{http_code}" "$@")
  if [ "$up" != "200" ]; then
    log "NO: $1 is not running (returned $up) - $comment"
    return 1
  else
    log "OK: running: $1 - $comment"
    return 0
  fi
}

# Set some variables
function setEnvironment() {
  # Rsync verbosity
  RSYNC_VERBOSE="-q"
  if [ "$VERBOSITY" != "-s" ]; then
    RSYNC_VERBOSE="-v"
  fi
}

function up() {
  setEnvironment

  mkdir -p structr/_data
  mkdir -p $SCENARIO_SRC_CACHEDIR
  pushd structr/_data > /dev/null

  # TODO: Remove certbot files from repository and create them or something
  local certdir=$SCENARIO_SERVER_CERTIFICATEDIR

  # Keystore
  banner "Keystore"
  if [ -f "keystore.pkcs12" ]; then
    logVerbose "Already existing keystore.pkcs12..."
  else
    logVerbose "Creating new keystore.pkcs12..."
    if [ -n "$certdir" ] && [ "$certdir"!="none" ] && [ -f "$certdir/fullchain.pem" ] && [ -f "$certdir/privkey.pem" ]; then
      echo "Using certificates from $certdir"
      ls -l "$certdir" > $VERBOSEPIPE
      ln -s "$certdir/fullchain.pem" fullchain.pem
      ln -s "$certdir/privkey.pem" privkey.pem
      openssl x509 -noout -fingerprint -sha256 -inform pem -in fullchain.pem > $VERBOSEPIPE
      openssl x509 -noout -fingerprint -sha1 -inform pem -in fullchain.pem > $VERBOSEPIPE
      openssl x509 -noout -text -inform pem -in fullchain.pem > $VERBOSEPIPE

      openssl pkcs12 -export -out keystore.pkcs12 -in fullchain.pem -inkey privkey.pem -password pass:qazwsx#123 > $VERBOSEPIPE
    else
      echo "ERROR: No certificates found!"
    fi
  fi

  # TODO: Use default structr server if file is a server or none
  # Workspace
  banner "Workspace ($SCENARIO_SRC_STRUCTR_DATAFILE)"
  if [ -d "WODA-current" ]; then
    logVerbose "Already existing workspace..."
  else
    logVerbose "Fetching workspace..."
    if [ ! -f "${SCENARIO_SRC_CACHEDIR}/WODA-current.tar.gz" ]; then
      rsync -azP $RSYNC_VERBOSE -L -e "ssh -o StrictHostKeyChecking=no" $SCENARIO_SRC_STRUCTR_DATAFILE ${SCENARIO_SRC_CACHEDIR}/WODA-current.tar.gz
    fi
    tar xzf ${SCENARIO_SRC_CACHEDIR}/WODA-current.tar.gz -C ./ > $VERBOSEPIPE
  fi

  # structr.zip
  banner "structr.zip"
  if [ -f "${SCENARIO_SRC_CACHEDIR}/structr.zip" ]; then
    logVerbose "Already existing structr.zip..."
  else
    logVerbose "Fetching structr.zip..."
    curl https://test.wo-da.de/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip -o ${SCENARIO_SRC_CACHEDIR}/structr.zip > $VERBOSEPIPE
  fi

  if [ ! -f "./structr.zip" ]; then
    cp "${SCENARIO_SRC_CACHEDIR}/structr.zip" .
  fi
  popd > /dev/null

  # Create structr image
  banner "Create structr image"
  log "Building image..."
  # Only pull if image contains a "/" (means it's a repository)
  if [[ $SCENARIO_STRUCTR_IMAGE == *"/"* ]]; then
    docker pull ${SCENARIO_STRUCTR_IMAGE}
  fi
  docker-compose build > $VERBOSEPIPE
  docker image ls > $VERBOSEPIPE

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
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps | grep $SCENARIO_NAME
  fi
}

function stop() {
  # Stop container
  banner "Stop container"
  docker-compose -p $SCENARIO_NAME stop
  docker ps | grep $SCENARIO_NAME
}

function down() {
  setEnvironment

  # Shutdown and remove containers
  banner "Shutdown and remove containers"
  docker-compose -p $SCENARIO_NAME down
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps
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
