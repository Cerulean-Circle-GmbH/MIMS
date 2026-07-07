#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env
. deploy-tools.sh

function setEnvironment() {
  deploy-tools.setEnvironment
}

function checkAndCreateDataVolume() {
  local creation_mode=$1
  banner "Check data volume"
  deploy-tools.checkAndCreateDataVolume SCENARIO_DATA_VOLUME_1 "data_storage" "$creation_mode"
}

function checkSmtpAuthFile() {
  local auth_file="${SCENARIO_SRC_SECRETSDIR}/${SCENARIO_MAILPIT_SMTPAUTHFILE}"

  if [ -z "${SCENARIO_MAILPIT_SMTPAUTHFILE:-}" ]; then
    logError "SCENARIO_MAILPIT_SMTPAUTHFILE must not be empty"
    return 1
  fi

  if [ ! -f "$auth_file" ]; then
    logError "Mailpit SMTP auth file not found: $auth_file"
    return 1
  fi

  if [ ! -r "$auth_file" ]; then
    logError "Mailpit SMTP auth file is not readable: $auth_file"
    return 1
  fi
}

function up() {
  checkSmtpAuthFile || return 1
  checkAndCreateDataVolume
  setEnvironment
  deploy-tools.up
}

function start() {
  checkSmtpAuthFile || return 1
  checkAndCreateDataVolume
  setEnvironment
  deploy-tools.start
}

function stop() {
  checkAndCreateDataVolume "nocreate"
  setEnvironment
  deploy-tools.stop
}

function down() {
  checkAndCreateDataVolume "nocreate"
  setEnvironment
  deploy-tools.down
}

function test() {
  checkSmtpAuthFile || return 1
  checkAndCreateDataVolume "nocreate"
  setEnvironment

  if [ "$VERBOSITY" = "-v" ]; then
    banner "Test"
    log "Volumes:"
    docker volume ls | grep -E "(${SCENARIO_DATA_VOLUME_1_PATH})"
    log ""
    log "Images:"
    docker image ls | grep mailpit
    log ""
    log "Containers:"
    docker ps --all | grep "${SCENARIO_NAME}_mailpit_container"
  fi

  banner "Check Mailpit $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
  deploy-tools.checkContainer "Mailpit (docker)" "${SCENARIO_NAME}_mailpit_container"
}

function logs() {
  checkAndCreateDataVolume "nocreate"
  setEnvironment
  deploy-tools.logs
}

function backup() {
  checkAndCreateDataVolume
  setEnvironment

  banner "Backup volumes"
  TIMESTAMP=$(date +%Y%m%d%H%M%S)
  deploy-tools.backupVolume SCENARIO_DATA_VOLUME_1_PATH "data_storage" "$SCENARIO_NAME" "$TIMESTAMP" "$SCENARIO_DATA_BACKUPDIR"
}

function restore() {
  checkAndCreateDataVolume
  setEnvironment

  banner "Restore volumes"
  echo "Available backups in $SCENARIO_DATA_BACKUPDIR:"
  ls -1 "$SCENARIO_DATA_BACKUPDIR" | grep "$SCENARIO_NAME" | grep data_storage | sed "s;${SCENARIO_NAME}_;;" | sed "s;_data_storage.*;;" | sort -u

  if [ -t 0 ]; then
    read -r -p "Please provide a timestamp to restore from (format: YYYYMMDDHHMMSS) : " TIMESTAMP
    if [ -z "$TIMESTAMP" ]; then
      logError "No timestamp provided"
      return 1
    fi
  else
    logError "Cannot prompt for input, not running in an interactive shell"
    return 1
  fi

  deploy-tools.restoreVolume SCENARIO_DATA_VOLUME_1_PATH "data_storage" "$SCENARIO_NAME" "$TIMESTAMP" "$SCENARIO_DATA_BACKUPDIR"
}

function update() {
  checkAndCreateDataVolume
  setEnvironment

  banner "Update services"
  docker compose -p "$SCENARIO_NAME" $COMPOSE_FILE_ARGUMENTS pull
  echo "Please restart the services to apply updates with down,up command manually!"
}

if [ -z "$1" ]; then
  deploy-tools.printUsage
  exit 1
fi

STEP=$1
shift
deploy-tools.parseArguments "$@"

case "$STEP" in
  up) up ;;
  start) start ;;
  stop) stop ;;
  down) down ;;
  test) test ;;
  logs) logs ;;
  backup) backup ;;
  restore) restore ;;
  update) update ;;
  *) deploy-tools.printUsage; exit 1 ;;
esac
