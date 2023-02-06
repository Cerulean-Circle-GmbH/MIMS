#!/bin/bash

# The startup should not stop in case of error!
set +e

echo "Starting custom start script: $0"

# Start ssh
service ssh restart

# Install once (only if it is not yet initialized)
source ~/config/user.env
ONCE_INITIALIZED=`once check.initialized  | grep "once not initialized" 2>/dev/null`
if [[ -n ${ONCE_INITIALIZED} ]]; then
    once init
    once domain.set localhost
    once stage next

    # Pre start once
    once start
    # The stop call might need to wait until once is really up
    # For now it seems to work
    once stop
fi

# Setup Git configuration
OUTER_GIT_CONFIG=/outer-config/.gitconfig
if [ -f ${OUTER_GIT_CONFIG} ]; then
    if [[ -z `git config --get user.name` || -z `git config --get user.email` ]]; then
        echo "Git name or email is not set, get configuration from ${OUTER_GIT_CONFIG}"
        git config --global include.path "/outer-config/.gitconfig"
    fi
    echo "Git name and email:"
    git config -l | grep user.
else
    echo "${OUTER_GIT_CONFIG} not found"
fi

# Setup SSH keys as new id in .ssh/ids
OUTER_SSH_CONFIG=/outer-config/.ssh
if [[ -d ${OUTER_SSH_CONFIG} && -f ${OUTER_SSH_CONFIG}/id_rsa ]]; then
    SSH_ID_DIR=~/.ssh/ids/ssh.outeruser
    SSH_CONFIG=~/.ssh/config
    if [[ ! -d ${SSH_ID_DIR} ]]; then
        echo "${SSH_ID_DIR} does not exist, copy keys from ${OUTER_SSH_CONFIG}"
        mkdir -p ${SSH_ID_DIR}
        cp -f ${OUTER_SSH_CONFIG}/id_rsa ${SSH_ID_DIR}/
        cp -f ${OUTER_SSH_CONFIG}/id_rsa.pub ${SSH_ID_DIR}/
        if [[ ! -f ${SSH_CONFIG}.ORIG ]]; then
            cp -f ${SSH_CONFIG} ${SSH_CONFIG}.ORIG
        fi
        cat ${SSH_CONFIG}.ORIG | sed "s;/home/developking/.ssh/id_rsa;/root/.ssh/ids/ssh.outeruser/id_rsa;" > ${SSH_CONFIG}
    fi
    ls -la ${SSH_ID_DIR}
else
    echo "${OUTER_SSH_CONFIG} or keys not found"
fi

# Install buildx extension
DOCKER_BUILDX_DIR=~/buildx
mkdir -p ${DOCKER_BUILDX_DIR}
pushd DOCKER_BUILDX_DIR
DOCKER_BUILDKIT=1
docker build --platform=local -o . "https://github.com/docker/buildx.git"
mkdir -p ~/.docker/cli-plugins
mv buildx ~/.docker/cli-plugins/docker-buildx
popd

# Start
cat startmsg/build.txt > startmsg/msg.txt
echo "Welcome to Web 4.0" >> startmsg/msg.txt
echo >> startmsg/msg.txt
echo "To start the ONCE server type:" >> startmsg/msg.txt
echo "   once restart" >> startmsg/msg.txt
echo "and then call: http://localhost:8080" >> startmsg/msg.txt
tail -f startmsg/msg.txt
