#!/bin/bash

# Get current dir
pushd $(dirname $0) > /dev/null
cwd=$(pwd)
popd > /dev/null

function banner() {
    echo
    echo "--- $1"
    echo
}

# Scenario vars
if [ -z "$1" ]; then
    echo "Usage: $0 <scenario>"
    echo "Example: $0 dev"
    exit 1
fi
SCENARIO_NAME=$1
source .env.$SCENARIO_NAME
source structr/.env
SCENARIOS_DIR_LOCAL=$cwd/_scenarios

# Setup scenario dir locally
banner "Setup scenario dir locally"
rm -rf $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
mkdir -p $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
cp -R -a src/* $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/
ENVIROMENT_VARIABLES=$(echo SCENARIO_NAME && cat .env.$SCENARIO_NAME structr/.env | grep -v ^# | grep -v ^$ | sed "s/=.*//")
for ENV_VAR in $ENVIROMENT_VARIABLES; do
    echo "$ENV_VAR=${!ENV_VAR}"
done > $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/.env

# Sync to remote and call on destination docker host
banner "Sync to remote and call on destination docker host"
ssh $SCENARIO_SERVER bash -s << EOF
mkdir -p $SCENARIOS_DIR_REMOTE/$SCENARIO_NAME
EOF
rsync -avzP --exclude=_data --delete $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/ $SCENARIO_SERVER:$SCENARIOS_DIR_REMOTE/$SCENARIO_NAME/
