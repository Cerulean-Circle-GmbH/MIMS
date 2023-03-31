#!/bin/bash

TAG=2023-03-31-01_19
# Use also tag here later
BRANCH=dev/neom
SERVER=backup.sfsre.com

BACKUP_STRUCTR_FILE=/var/backups/structr/backup-structr-${TAG}_WODA-current.tar.gz


# Script is called on destination docker host

# Startup WODA with WODA.2023 container

# Run script in this container

## Get backup
## Setup structr scenario
## Start structr
## Reconfigure ONCE server
## Start ONCE server