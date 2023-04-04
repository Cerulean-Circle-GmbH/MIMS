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

# Scenario vars
SCENARIO_NAME=dev
SCENARIO_TAG=2023-03-31-01_19
SCENARIO_BRANCH=dev/neom # Use also tag here later
SCENARIO_SERVER=backup.sfsre.com
SCENARIO_CONTAINER=$SCENARIO_NAME-once.sh_container
SCENARIO_ONCE_HTTP=9080
SCENARIO_ONCE_HTTPs=9443
SCENARIO_ONCE_SSH=9022
SCENARIO_DOMAIN=localhost

BACKUP_STRUCTR_FILE=/var/backups/structr/backup-structr-${TAG}_WODA-current.tar.gz
STRUCTUR_ZIP=/var/dev/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip
SCENARIOS_DIR_REMOTE=/var/dev/ONCE.2023-Scenarios
SCENARIOS_DIR_LOCAL=$cwd/_scenarios

# Setup scenario dir locally
banner "Setup scenario dir locally"
rm -rf $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
mkdir -p $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
cp -R docker-compose.yml scenario.*.sh structr certbot $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/
cat << EOF > $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/.env
SCENARIO_NAME=$SCENARIO_NAME
SCENARIO_CONTAINER=$SCENARIO_CONTAINER
SCENARIO_ONCE_HTTP=$SCENARIO_ONCE_HTTP
SCENARIO_ONCE_HTTPS=$SCENARIO_ONCE_HTTPs
SCENARIO_ONCE_SSH=$SCENARIO_ONCE_SSH
SCENARIO_DOMAIN=$SCENARIO_DOMAIN
defaultWorkspace=/EAMD.ucp
defaultServer=https://$SCENARIO_DOMAIN
structr_dir=./WODA-current
files_dir=/EAMD.ucp
STRUCTR_UID=0
STRUCTR_GID=33
SCENARIO_STRUCTR_HTTP=8082
SCENARIO_STRUCTR_HTTPS=8083
SCENARIO_STRUCTR_FTP=8021
SCENARIO_STRUCTR_EXTRA=7574
EOF
#cp $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/.env $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/structr/

# Cleanup remotely
banner "Cleanup remotely"
callRemote ./scenario.cleanup.sh || true

# Sync to remote and call on destination docker host
banner "Sync to remote and call on destination docker host"
ssh $SCENARIO_SERVER bash -s << EOF
mkdir -p $SCENARIOS_DIR_REMOTE/$SCENARIO_NAME
EOF
rsync -avzP --delete $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/ $SCENARIO_SERVER:$SCENARIOS_DIR_REMOTE/$SCENARIO_NAME/

# Startup WODA with WODA.2023 container and check that startup is done
banner "Startup WODA with WODA.2023 container and check that startup is done"
callRemote ./scenario.install.sh

# Restart once server
banner "Restart once server"
callRemote ./scenario.start.sh

# Check running servers
banner "Check http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp"
up=$(curl -s -o /dev/null -w "%{http_code}" http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp)
if [ "$up" != "200" ]; then
  echo "ERROR: http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp is not running"
  exit 1
else
    echo "OK: http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp is running"
fi

## Get backup
## Setup structr scenario
## Start structr
## Reconfigure ONCE server
## Start ONCE server