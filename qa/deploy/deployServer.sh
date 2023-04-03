#!/bin/bash

# Get current dir
pushd $(dirname $0) > /dev/null
cwd=$(pwd)
popd > /dev/null

# Scenario vars
SCENARIO_NAME=dev
SCENARIO_TAG=2023-03-31-01_19
SCENARIO_BRANCH=dev/neom # Use also tag here later
SCENARIO_SERVER=backup.sfsre.com
SCENARIO_CONTAINER=$SCENARIO_NAME-once.sh_container
SCENARIO_ONCE_HTTP=9080
SCENARIO_ONCE_HTTPs=9443
SCENARIO_ONCE_SSH=9022

BACKUP_STRUCTR_FILE=/var/backups/structr/backup-structr-${TAG}_WODA-current.tar.gz
STRUCTUR_ZIP=/var/dev/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip
SCENARIOS_DIR_REMOTE=/var/dev/ONCE.2023-Scenarios
SCENARIOS_DIR_LOCAL=$cwd/_scenarios

# Setup scenario dir locally
rm -rf $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
mkdir -p $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
cp docker-compose.yml $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/
# echo environemnt with EOF
cat << EOF > $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/.env
SCENARIO_NAME=$SCENARIO_NAME
SCENARIO_CONTAINER=$SCENARIO_CONTAINER
SCENARIO_ONCE_HTTP=$SCENARIO_ONCE_HTTP
SCENARIO_ONCE_HTTPS=$SCENARIO_ONCE_HTTPs
SCENARIO_ONCE_SSH=$SCENARIO_ONCE_SSH
EOF

# Cleanup remotely
ssh $SCENARIO_SERVER bash -s << EOF
cd $SCENARIOS_DIR_REMOTE/$SCENARIO_NAME
docker-compose -p $SCENARIO_NAME down
docker volume rm ${SCENARIO_NAME}_var_dev
rm -rf $SCENARIOS_DIR_REMOTE/$SCENARIO_NAME
docker ps
docker volume ls
EOF

# Sync to remote and call on destination docker host
ssh $SCENARIO_SERVER bash -s << EOF
mkdir -p $SCENARIOS_DIR_REMOTE/$SCENARIO_NAME
EOF
rsync -avzP $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/ $SCENARIO_SERVER:$SCENARIOS_DIR_REMOTE/$SCENARIO_NAME/

# Startup WODA with WODA.2023 container and check that startup is done
ssh $SCENARIO_SERVER bash -s << EOF
cd $SCENARIOS_DIR_REMOTE/$SCENARIO_NAME
cat .env
docker-compose -p $SCENARIO_NAME up -d
docker ps
# Wait for startup
found=""
while [ -z "\$found" ]; do
  echo "Waiting for startup..."
  sleep 1
  timeout 5s docker logs --follow $SCENARIO_CONTAINER
  found=\$(docker logs $SCENARIO_CONTAINER 2>/dev/null | grep "Welcome to Web 4.0")
done
echo "Startup done (\$found)"
EOF

# Restart once server
ssh $SCENARIO_SERVER bash -s << EOF
docker exec dev-once.sh_container bash -c "source ~/config/user.env && once restart"
echo "ONCE server restarted"
EOF

# Check running servers
echo "Check http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp"
up=$(curl -s -o /dev/null -w "%{http_code}" http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp)
if [ "$up" != "200" ]; then
  echo "ERROR: http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp is not running"
  exit 1
fi

## Get backup
## Setup structr scenario
## Start structr
## Reconfigure ONCE server
## Start ONCE server