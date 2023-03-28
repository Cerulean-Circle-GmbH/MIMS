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

# Create tar
banner "Create $tarfile"
tar czf --exclude "var/jenkins_home/workspace" $tarfile /var/jenkins_home

# Copy to backup server
banner "Copy to backup server"
rsync -avzP -e "ssh $use_key -o 'StrictHostKeyChecking no'" $tarfile backup.sfsre.com:/var/backups/jenkins/