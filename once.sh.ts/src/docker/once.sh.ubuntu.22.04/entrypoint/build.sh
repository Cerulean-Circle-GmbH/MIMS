#!/bin/bash
set -e

echo "Starting custom build script: $PWD $0"
export OOSH_SSH_CONFIG_HOST="dockerSSH.once2023"

# Temporary log settings
#export LOG_LEVEL=3
#export LOG_DEVICE="$HOME/build-initial-oosh.log"

# Remove, when sudo in oosh is fixed
apt install git -y

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

# Add test user
#useradd -rm -d /home/ubuntu -s /bin/bash -g root -G sudo -u 1000 test 
#echo 'test:test' | chpasswd
#echo 'root:test' | sudo chpasswd

# generate server keys
#ssh-keygen -A
##RUN ssh-keygen -t dsa -N "my passphrase" -C "test key" -f mykey
##ssh-keygen -t rsa -q -f "$HOME/.ssh/id_rsa" -N ""

# allow root to login
#sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
#sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config

# Install once
once init
once domain.set localhost
once stage next