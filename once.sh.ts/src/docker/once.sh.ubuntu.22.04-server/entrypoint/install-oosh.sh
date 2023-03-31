#!/bin/bash

export OOSH_SSH_CONFIG_HOST="docker.once.ssh"

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
    cd ${OOSH_DIR} && git checkout ${OOSH_BRANCH}
fi

echo "custom build script: $PWD $0"
echo "====== DONE ================="

### migrate this code into the state machine

cd ~
source ~/config/user.env

# Install stuff
oo cmd net-tools
oo cmd openssh-server
oo cmd errno

# Install docker
oo cmd docker.io
oo cmd docker-compose

# Update once.sh
oo update
