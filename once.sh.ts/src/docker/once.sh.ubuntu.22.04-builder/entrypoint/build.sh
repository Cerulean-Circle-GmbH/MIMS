#!/bin/bash
set -e

mkdir -p startmsg
NOW=`date`
echo "This container was build: $NOW" > startmsg/build.txt

echo "Starting custom build script: $PWD $0"
export OOSH_SSH_CONFIG_HOST="docker.once.builder"

# Import _env to see what you want to build (default: from web with branch main) (see devTool)
if [ -f /root/entrypoint/_env ]; then
    source /root/entrypoint/_env
fi

# Download and install oosh
if [ ! -z ${OOSH_TAR} ] && [ -f ${OOSH_TAR} ]; then
    export OOSH_INSTALL_SOURCE="/root/entrypoint/install.oosh.source"
    echo "<build.sh> Install oosh from ${OOSH_INSTALL_SOURCE}"
    mkdir -p ${OOSH_INSTALL_SOURCE}
    tar xf ${OOSH_TAR} -C ${OOSH_INSTALL_SOURCE}
    ${OOSH_INSTALL_SOURCE}/init/oosh
else
    if [ -z ${OOSH_BRANCH} ]; then
        export OOSH_BRANCH="main"
    fi
    export OOSH_INSTALL_SOURCE="https://raw.githubusercontent.com/Cerulean-Circle-GmbH/once.sh/${OOSH_BRANCH}/init/oosh"
    echo "<build.sh> Install oosh from ${OOSH_INSTALL_SOURCE}"
    echo "<build.sh> Install oosh with branch ${OOSH_BRANCH}"
    env sh -c "$(wget -O- ${OOSH_INSTALL_SOURCE})"
fi

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

# Install npm packages
npm install wavi -g

# Setup ssh and root login
echo 'root:once' | chpasswd
mkdir /var/run/sshd
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
