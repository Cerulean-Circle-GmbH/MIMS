#!/bin/bash

# Get current dir
pushd $(dirname $0) > /dev/null
cwd=$(pwd)
popd > /dev/null

function callRemote() {
    ssh $SCENARIO_SERVER bash -s << EOF
cd $SCENARIOS_DIR_REMOTE/$SCENARIO_NAME
$@
EOF
}

function banner() {
    echo
    echo "####################################################################################################"
    echo "## $@"
    echo "####################################################################################################"
    echo
}

function checkURL() {
    up=$(curl -s -o /dev/null -w "%{http_code}" $1)
    if [ "$up" != "200" ]; then
        echo "ERROR: $1 is not running (returned $up)"
    else
        echo "OK: $1 is running"
    fi
}

# Scenario vars
SCENARIO_NAME=dev
SCENARIO_TAG=2023-03-31-01_19
SCENARIO_BRANCH=dev/neom # Use also tag here later
SCENARIO_SERVER=backup.sfsre.com
SCENARIO_CONTAINER=$SCENARIO_NAME-once.sh_container
SCENARIO_ONCE_HTTP=9080
SCENARIO_ONCE_HTTPS=9443
SCENARIO_ONCE_SSH=9022
SCENARIO_DOMAIN=localhost
SCENARIO_STRUCTR_SERVER=https://$SCENARIO_DOMAIN
SCENARIO_STRUCTR_DIR=./structr/_data/WODA-current
# MKT: TODO: Why this?
SCENARIO_STRUCTR_FILES_DIR=/var/dev/EAMD.ucp
SCENARIO_STRUCTR_UID=0
SCENARIO_STRUCTR_GID=33
SCENARIO_STRUCTR_HTTP=8082
SCENARIO_STRUCTR_HTTPS=8083
SCENARIO_STRUCTR_FTP=8021
SCENARIO_STRUCTR_EXTRA=7574
SCENARIO_STRUCTR_DATA_SRC_FILE=backup.sfsre.com:/var/backups/structr/backup-structr-${SCENARIO_TAG}_WODA-current.tar.gz

STRUCTUR_ZIP=/var/dev/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip
SCENARIOS_DIR_REMOTE=/var/dev/ONCE.2023-Scenarios
SCENARIOS_DIR_LOCAL=$cwd/_scenarios

# Setup scenario dir locally
banner "Setup scenario dir locally"
rm -rf $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
mkdir -p $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
cp -R -a docker-compose.yml scenario.*.sh structr certbot $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/
cat << EOF > $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/.env
SCENARIO_NAME=$SCENARIO_NAME
SCENARIO_BRANCH=$SCENARIO_BRANCH
SCENARIO_CONTAINER=$SCENARIO_CONTAINER
SCENARIO_ONCE_HTTP=$SCENARIO_ONCE_HTTP
SCENARIO_ONCE_HTTPS=$SCENARIO_ONCE_HTTPS
SCENARIO_ONCE_SSH=$SCENARIO_ONCE_SSH
SCENARIO_DOMAIN=$SCENARIO_DOMAIN
SCENARIO_STRUCTR_SERVER=$SCENARIO_STRUCTR_SERVER
SCENARIO_STRUCTR_DIR=$SCENARIO_STRUCTR_DIR
SCENARIO_STRUCTR_FILES_DIR=$SCENARIO_STRUCTR_FILES_DIR
SCENARIO_STRUCTR_UID=$SCENARIO_STRUCTR_UID
SCENARIO_STRUCTR_GID=$SCENARIO_STRUCTR_GID
SCENARIO_STRUCTR_HTTP=$SCENARIO_STRUCTR_HTTP
SCENARIO_STRUCTR_HTTPS=$SCENARIO_STRUCTR_HTTPS
SCENARIO_STRUCTR_FTP=$SCENARIO_STRUCTR_FTP
SCENARIO_STRUCTR_EXTRA=$SCENARIO_STRUCTR_EXTRA
SCENARIO_STRUCTR_DATA_SRC_FILE=$SCENARIO_STRUCTR_DATA_SRC_FILE
EOF

# Cleanup remotely
banner "Cleanup remotely"
callRemote ./scenario.cleanup.sh || true

# Sync to remote and call on destination docker host
banner "Sync to remote and call on destination docker host"
ssh $SCENARIO_SERVER bash -s << EOF
mkdir -p $SCENARIOS_DIR_REMOTE/$SCENARIO_NAME
EOF
rsync -avzP --exclude=_data --delete $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/ $SCENARIO_SERVER:$SCENARIOS_DIR_REMOTE/$SCENARIO_NAME/

# Startup WODA with WODA.2023 container and check that startup is done
banner "Startup WODA with WODA.2023 container and check that startup is done"
callRemote ./scenario.install.sh

# Restart once server
banner "Restart once server"
callRemote ./scenario.start.sh

# Check running servers
banner "Check running servers"
checkURL http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/
checkURL https://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTPS/EAMD.ucp/
checkURL http://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTP/structr/
checkURL https://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTPS/structr/

## Reconfigure ONCE server and connect structr
ssh $SCENARIO_SERVER bash -s << EOF
source /root/.once
export ONCE_REVERSE_PROXY_CONFIG='[["auth","test.wo-da.de"],["snet","test.wo-da.de"],["structr","$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTP"]]'
CF=\$ONCE_DEFAULT_SCENARIO/.once
mv \$CF \$CF.ORIG
cat \$CF.ORIG | line replace "ONCE_REVERSE_PROXY_CONFIG=.*" "ONCE_REVERSE_PROXY_CONFIG='\$ONCE_REVERSE_PROXY_CONFIG'" > \$CF
EOF
callRemote source /root/.once && echo $ONCE_DEFAULT_SCENARIO/.once && cat $ONCE_DEFAULT_SCENARIO/.once
