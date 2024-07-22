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

    # Adapt revers proxy configuration for connection to structr server
    export ONCE_REVERSE_PROXY_CONFIG='[["auth","test.wo-da.de"],["snet","test.wo-da.de"],["structr","test.wo-da.de"]]'
    export ONCE_REV_PROXY_HOST="0.0.0.0"
    export ONCE_STRUCTR_SERVER="https://localhost:${ONCE_DOCKER_REVERSE_PROXY_HTTPS_PORT}"

    # Adapt configuration for "once test"
    export ONCE_DEFAULT_URL=https://localhost:8443
    export ONCE_DIRECT_HTTPS_URL=https://localhost:8443
    export ONCE_DEFAULT_UDE_STORE=https://localhost:8443
    export ONCE_DEFAULT_URL=https://localhost:8443
    export ONCE_DEFAULT_KEYCLOAK_SERVER='{ "realm": "master", "clientId": "shifternetzwerk", "testClient": { "client_id": "mochaAPI", "client_secret": "df37971a-f098-4310-8a62-b238b15c7b35" , "mocha1id": "42b8c48b-34d6-4a33-8c93-5e3782c05a48", "mocha2id": "ccfff6f6-7764-4111-98f3-6bf68d8e4b26", "mocha3id": "92746ce6-d5ce-4127-9e45-30fef19cf7a6" }, "url": "https://test.wo-da.de/auth"}'

    # Save adapted configuration
    CF=$ONCE_DEFAULT_SCENARIO/.once
    mv $CF $CF.ORIG
    cat $CF.ORIG | sed "s;ONCE_REVERSE_PROXY_CONFIG=.*;ONCE_REVERSE_PROXY_CONFIG='$ONCE_REVERSE_PROXY_CONFIG';" | \
                   sed "s;ONCE_REV_PROXY_HOST=.*;ONCE_REV_PROXY_HOST='$ONCE_REV_PROXY_HOST';" | \
                   sed "s;ONCE_STRUCTR_SERVER=.*;ONCE_STRUCTR_SERVER='$ONCE_STRUCTR_SERVER';" | \
                   sed "s;ONCE_DEFAULT_URL=.*;ONCE_DEFAULT_URL='$ONCE_DEFAULT_URL';" | \
                   sed "s;ONCE_DIRECT_HTTPS_URL=.*;ONCE_DIRECT_HTTPS_URL='$ONCE_DIRECT_HTTPS_URL';" | \
                   sed "s;ONCE_DEFAULT_UDE_STORE=.*;ONCE_DEFAULT_UDE_STORE='$ONCE_DEFAULT_UDE_STORE';" | \
                   sed "s;ONCE_DEFAULT_URL=.*;ONCE_DEFAULT_URL='$ONCE_DEFAULT_URL';" | \
                   sed "s;ONCE_DEFAULT_KEYCLOAK_SERVER=.*;ONCE_DEFAULT_KEYCLOAK_SERVER='$ONCE_DEFAULT_KEYCLOAK_SERVER';" > $CF
fi