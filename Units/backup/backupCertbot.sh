#!/bin/bash

banner() {
  echo
  echo "============================================="
  echo $1
  echo "============================================="
}

# Work in build dir
mkdir -p _build
cd _build

# Initialization
date=$(date +%Y-%m-%d-%H_%M)
if [[ -n "${keyfile}" ]]; then
  echo "Use ${keyfile}"
  use_key="-i ${keyfile}"
fi

CERTBOT_CONFIG_DIR="/var/dev/ssl/data/certbot"
LOCAL_CONFIG_DIR="./certbot"
BACKUP_DIR="/var/backups/test.wo-da.de_certbot"
BACKUP_DESTINATION="backup.sfsre.com:$BACKUP_DIR"

# Get certbot directory
banner "Get certbot directory"
mkdir -p $LOCAL_CONFIG_DIR
rsync -avzP -e "ssh $use_key -o 'StrictHostKeyChecking no'" WODA.test:$CERTBOT_CONFIG_DIR/ $LOCAL_CONFIG_DIR/
tar -czf certbot-${date}.tar.gz $LOCAL_CONFIG_DIR

# Copy to backup server
banner "Copy to backup server"
rsync -avzP -e "ssh $use_key -o 'StrictHostKeyChecking no'" certbot-${date}.tar.gz $BACKUP_DESTINATION

# Show backup
banner "Show backup"
ssh $use_key -o 'StrictHostKeyChecking no' backup.sfsre.com ls -l $BACKUP_DIR
