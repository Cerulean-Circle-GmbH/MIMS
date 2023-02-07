#!/bin/bash
set -e

mkdir -p startmsg
NOW=`date`
echo "This container was build: $NOW" > startmsg/build.txt

echo "Starting custom build script: $PWD $0"
export OOSH_SSH_CONFIG_HOST="docker.once.ssh"

# Temporary log settings
#export LOG_LEVEL=3
#export LOG_DEVICE="$HOME/build-initial-oosh.log"

# Download and install oosh
env sh -c "$(wget -O- https://raw.githubusercontent.com/Cerulean-Circle-GmbH/once.sh/main/init/oosh)"
source ~/config/user.env

echo "custom build script: $PWD $0"
echo "====== DONE ================="

### migrate this code into the state machine

# Install stuff
oo cmd net-tools
oo cmd openssh-server
oo cmd errno

# Install docker
oo cmd docker.io
oo cmd docker-compose

# Setup ssh and root login
echo 'root:once' | chpasswd
mkdir /var/run/sshd
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
