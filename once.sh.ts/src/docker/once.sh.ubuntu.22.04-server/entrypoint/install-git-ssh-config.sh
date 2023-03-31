#!/bin/bash

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
OUTER_SSH_KEY_NAME=id_rsa
if [[ -d ${OUTER_SSH_CONFIG} && -f ${OUTER_SSH_CONFIG}/${OUTER_SSH_KEY_NAME} ]]; then
    SSH_ID_DIR=~/.ssh/ids/ssh.outeruser
    SSH_CONFIG=~/.ssh/config
    if [[ ! -d ${SSH_ID_DIR} ]]; then
        echo "${SSH_ID_DIR} does not exist, copy keys from ${OUTER_SSH_CONFIG}"
        mkdir -p ${SSH_ID_DIR}
        cp -f ${OUTER_SSH_CONFIG}/${OUTER_SSH_KEY_NAME} ${SSH_ID_DIR}/
        cp -f ${OUTER_SSH_CONFIG}/${OUTER_SSH_KEY_NAME}.pub ${SSH_ID_DIR}/
        chmod 400 ${SSH_ID_DIR}/${OUTER_SSH_KEY_NAME} ${SSH_ID_DIR}/${OUTER_SSH_KEY_NAME}.pub
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
            cp ~/.ssh/ids/${MY_IDNAME}/${OUTER_SSH_KEY_NAME}.pub ~/.ssh/public_keys/
            MY_KEY=/root/.ssh/ids/${MY_IDNAME}/${OUTER_SSH_KEY_NAME}
            cat ${SSH_SOURCE_CONFIG} | sed "s;/home/developking/.ssh/${OUTER_SSH_KEY_NAME};${MY_KEY};" | sed "s;~/.ssh/${OUTER_SSH_KEY_NAME};${MY_KEY};" > ${SSH_CONFIG}
        else
            cat ${SSH_SOURCE_CONFIG} | sed "s;/home/developking/.ssh/${OUTER_SSH_KEY_NAME};/root/.ssh/ids/ssh.outeruser/${OUTER_SSH_KEY_NAME};" > ${SSH_CONFIG}
        fi
    fi
    ls -la ${SSH_ID_DIR}
else
    echo "${OUTER_SSH_CONFIG} or keys not found"
fi
