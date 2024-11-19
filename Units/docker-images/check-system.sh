#!/bin/sh
#http://www.etalabs.net/sh_tricks.html

log() {
  echo "$@" > $LOG_DEVICE
}

log_part() {
  printf "$@" > $LOG_DEVICE
}

usage() {
  log "Checking your system...
    "
  log "to supress output, next time type"
  log "  $0 silent
    "
  check "$@"
}

check() {
  log "checking ..."
  check_cmd git
  #check_cmd once.sh
  check_this
  check_once

  log "checking state...
    "
  state list all
  log "checking oo state...
    "
  oo mode

  check_bash

  log "\033[1;32m"
  log "SUCCESS\033[0m"
  log "\033[32mWeb 4.0 is enabled\033[0m"
}

check_cmd() {
  log_part "  command: $1\t"
  if ! [ -x "$(command -v "$1")" ]; then
    log "no command: $1"
    exit 2
  else
    log "   ...ok"
    log_part "\t\t"
    which "$1"
  fi
}

check_once() {
  check_cmd once
  which once
  once version
  log "\033[1;32m"
  log "SUCCESS\033[0m"
  log "\033[32monce is already available\033[0m

    "

}

check_this() {
  check_cmd this
  which this

  log ""
  log "\033[1;32mSUCCESS\033[0m"
  log "\033[32mThe Object Oriented SHELL 'oosh' is aready available.\033[0m


    "
}

check_bash() {
  isInBash=$(ps -o ppid,command= $PPID | line find bash)
  if [ -z "$isInBash" ]; then

    log "\033[1;31mNot in OOSH\033[0m"
    log "
        to enter the  Object Oriented SHELL 'oosh' type

        this
        "
    exit 1
  else
    log ""
    log "isInBash=\"$isInBash\"
        "
    log "\033[1;32mSUCCESS\033[0m"
    log "\033[32mYou are within the Object Oriented SHELL 'oosh' aready...\033[0m


        "
  fi
}

start() {
  LOG_DEVICE=/dev/tty
  #log "parameters: $@"
  if [ -n "$1" ]; then
    #log "got parameters: $@"
    while [ -n $1 ]; do
      case $1 in
        fail)
          return 1
          ;;
        error)
          shift
          return "$1"
          ;;
        silent)
          LOG_DEVICE=/dev/null
          ;;
        mode)
          log "got: mode"
          ;;
        *)
          log "processing: $*"
          #this.call "$@"
          ;;
      esac
      shift
      #log "next parameter: =$1="
      if [ -z "$1" ]; then
        log ciao
        return 0
      fi
    done
    #return 0
  else
    usage
    return 0
  fi
}

start "$@"
