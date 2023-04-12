#!/bin/bash

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

    # Adapt git config
    cd /var/dev/EAMD.ucp
    git config pull.rebase false
    
    # Adapt once config
    if [ -z $ONCE_DOCKER_REVERSE_PROXY_HTTPS_PORT ]; then
        export ONCE_DOCKER_REVERSE_PROXY_HTTPS_PORT=5005
    fi
    if [ -z $ONCE_DOCKER_REVERSE_PROXY_HTTP_PORT ]; then
        export ONCE_DOCKER_REVERSE_PROXY_HTTP_PORT=5002
    fi
    source /root/.once
    export ONCE_REVERSE_PROXY_CONFIG='[["auth","test.wo-da.de"],["snet","test.wo-da.de"],["structr","test.wo-da.de"]]'
    export ONCE_REV_PROXY_HOST="0.0.0.0"
    export ONCE_STRUCTR_SERVER="https://localhost:${ONCE_DOCKER_REVERSE_PROXY_HTTPS_PORT}"

    CF=$ONCE_DEFAULT_SCENARIO/.once
    mv $CF $CF.ORIG
    cat $CF.ORIG | sed "s;ONCE_REVERSE_PROXY_CONFIG=.*;ONCE_REVERSE_PROXY_CONFIG='$ONCE_REVERSE_PROXY_CONFIG';" | \
                   sed "s;ONCE_REV_PROXY_HOST=.*;ONCE_REV_PROXY_HOST='$ONCE_REV_PROXY_HOST';" | \
                   sed "s;ONCE_STRUCTR_SERVER=.*;ONCE_STRUCTR_SERVER='$ONCE_STRUCTR_SERVER';" > $CF
fi