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
SCENARIOS_DIR_LOCAL=$cwd/_scenarios

# Setup scenario dir locally
banner "Setup scenario dir locally"
rm -rf $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
mkdir -p $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME
cp -R -a docker-compose.yml scenario.*.sh structr certbot $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/
cp .env.$SCENARIO_NAME $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/.env
cat local.scenario.test.sh | sed "s/source .env.*/source .env/" > $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/scenario.test.sh

# Sync to remote and call on destination docker host
banner "Sync to remote and call on destination docker host"
ssh $SCENARIO_SERVER bash -s << EOF
mkdir -p $SCENARIOS_DIR_REMOTE/$SCENARIO_NAME
EOF
rsync -avzP --exclude=_data --delete $SCENARIOS_DIR_LOCAL/$SCENARIO_NAME/ $SCENARIO_SERVER:$SCENARIOS_DIR_REMOTE/$SCENARIO_NAME/
