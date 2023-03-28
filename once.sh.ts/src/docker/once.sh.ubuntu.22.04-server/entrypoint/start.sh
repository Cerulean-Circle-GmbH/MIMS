#!/bin/bash

# The startup should not stop in case of error!
set +e

echo "Starting custom start script: $0"
cat ~/startmsg/build.txt > ~/startmsg/msg.txt
echo >> ~/startmsg/msg.txt
echo "Timing:" >> ~/startmsg/msg.txt
echo "start.sh:$LINENO: $(date)" >> ~/startmsg/msg.txt

# https://github.com/remotemobprogramming/mob
#curl -sL install.mob.sh | sh
#go install github.com/remotemobprogramming/mob/v3@latest

# Start ssh
service ssh restart

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

cd ~
source ~/config/user.env

echo "custom build script: $PWD $0"
echo "====== DONE ================="

echo "start.sh:$LINENO: $(date)" >> ~/startmsg/msg.txt

### migrate this code into the state machine

# Install stuff
oo cmd net-tools
oo cmd openssh-server
oo cmd errno

# Install docker
oo cmd docker.io
oo cmd docker-compose

# Update once.sh
oo update

echo "start.sh:$LINENO: $(date)" >> ~/startmsg/msg.txt

# Install once (only if it is not yet initialized)
source ~/config/user.env
ONCE_INITIALIZED=`once check.initialized  | grep "once not initialized" 2>/dev/null`
if [[ -n ${ONCE_INITIALIZED} ]]; then
    once init
    once domain.set localhost
    once stage next
    once stage next
    once stage next # install certificates

    # Pre start once
    once start
    # The stop call might need to wait until once is really up
    # For now it seems to work
    once stop

    source /root/.once
    export ONCE_REVERSE_PROXY_CONFIG='[["auth","test.wo-da.de"],["snet","test.wo-da.de"],["structr","test.wo-da.de"]]'
    echo "export ONCE_REVERSE_PROXY_CONFIG='$ONCE_REVERSE_PROXY_CONFIG'" >> $ONCE_DEFAULT_SCENARIO/.once
fi

echo "start.sh:$LINENO: $(date)" >> ~/startmsg/msg.txt

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
        chmod 600 ${SSH_ID_DIR}/id_rsa*
        if [[ ! -f ${SSH_CONFIG}.ORIG ]]; then
            cp -f ${SSH_CONFIG} ${SSH_CONFIG}.ORIG
        fi
        SSH_SOURCE_CONFIG=${SSH_CONFIG}.ORIG
        if [[ -f ${OUTER_SSH_CONFIG}/config ]]; then
            SSH_SOURCE_CONFIG=${OUTER_SSH_CONFIG}/config
        fi

        # create pushable keys and configure for WODA.test, WODA.dev, WODA.prod
        GIT_EMAIL=`git config --get user.email | sed "s;@;.;"`
        if [ -n $GIT_EMAIL ]; then
            MY_IDNAME=ssh.$GIT_EMAIL
            ossh id.create.fromKey ${MY_IDNAME} ${SSH_ID_DIR}
            cp ~/.ssh/ids/${MY_IDNAME}/id_rsa.pub ~/.ssh/public_keys/
            MY_KEY=/root/.ssh/ids/${MY_IDNAME}/id_rsa
            cat ${SSH_SOURCE_CONFIG} | sed "s;/home/developking/.ssh/id_rsa;${MY_KEY};" | sed "s;~/.ssh/id_rsa;${MY_KEY};" > ${SSH_CONFIG}
        else
            cat ${SSH_SOURCE_CONFIG} | sed "s;/home/developking/.ssh/id_rsa;/root/.ssh/ids/ssh.outeruser/id_rsa;" > ${SSH_CONFIG}
        fi
    fi
    ls -la ${SSH_ID_DIR}
else
    echo "${OUTER_SSH_CONFIG} or keys not found"
fi

# Start
echo "start.sh:$LINENO: $(date)" >> ~/startmsg/msg.txt
echo >> ~/startmsg/msg.txt

echo "Welcome to Web 4.0" >> ~/startmsg/msg.txt
echo >> ~/startmsg/msg.txt
echo "To start the ONCE server type:" >> ~/startmsg/msg.txt
echo "   once restart" >> ~/startmsg/msg.txt
if [ -z "$ONCE_DOCKER_HTTP_PORT" ]; then
    export ONCE_DOCKER_HTTP_PORT=8080
    export ONCE_DOCKER_HTTPS_PORT=8443
fi
echo "and then call: http://localhost:${ONCE_DOCKER_HTTP_PORT} or https://localhost:${ONCE_DOCKER_HTTPS_PORT}" >> ~/startmsg/msg.txt
tail -f ~/startmsg/msg.txt
