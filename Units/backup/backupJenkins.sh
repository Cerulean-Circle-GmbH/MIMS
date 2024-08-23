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
tarfile=backup-jenkins-${date}.tar.gz
rm -rf backup-jenkins-*
if [[ -n "${keyfile}" ]]; then
  echo "Use ${keyfile}"
  use_key="-i ${keyfile}"
fi

BACKUP_DIR="/var/backups/test.wo-da.de_jenkins"
BACKUP_DESTINATION="backup.sfsre.com:$BACKUP_DIR"

# Create tar
banner "Create $tarfile"
tar --exclude "/var/jenkins_home/workspace" -czf $tarfile /var/jenkins_home

# Copy to backup server
banner "Copy to backup server"
rsync -avzP -e "ssh $use_key -o 'StrictHostKeyChecking no'" $tarfile $BACKUP_DESTINATION/
