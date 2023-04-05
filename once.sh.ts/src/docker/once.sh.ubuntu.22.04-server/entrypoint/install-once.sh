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

    # Adapt once config
    source /root/.once
    export ONCE_REVERSE_PROXY_CONFIG='[["auth","test.wo-da.de"],["snet","test.wo-da.de"],["structr","test.wo-da.de"]]'
    CF=$ONCE_DEFAULT_SCENARIO/.once
    mv $CF $CF.ORIG
    cat $CF.ORIG | line replace "ONCE_REVERSE_PROXY_CONFIG=.*" "ONCE_REVERSE_PROXY_CONFIG='$ONCE_REVERSE_PROXY_CONFIG'" > $CF
fi