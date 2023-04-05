#!/bin/bash

# Get current dir
pushd $(dirname $0) > /dev/null
cwd=$(pwd)
popd > /dev/null

function banner() {
    echo
    echo "####################################################################################################"
    echo "## $@"
    echo "####################################################################################################"
    echo
}

function callRemote() {
    ssh $SCENARIO_SERVER bash -s << EOF
cd $SCENARIOS_DIR_REMOTE/$SCENARIO_NAME
$@
EOF
}

# See also:
# /var/dev/EAMD.ucp/Components/com/ceruleanCircle/EAM/1_infrastructure/NewUserStuff/scripts/structr.initApps
# /var/dev/EAMD.ucp/Components/com/ceruleanCircle/EAM/1_infrastructure/DockerWorkspaces/WODA/1.0.0/Alpine/3.13.2/Openjdk

# TODO: Struktur EAM/.... beachten
# TODO: snet startup needs still a once restart, why?
# TODO: Tag dev/neom version with structr backup

# Scenario vars
if [ -z "$1" ]; then
    echo "Usage: $0 <scenario>"
    echo "Example: $0 dev"
    exit 1
fi
SCENARIO_NAME=$1
source .env.$SCENARIO_NAME

# Cleanup remotely
banner "Cleanup remotely"
callRemote ./scenario.cleanup.sh || true

# Init locally and sync remote
./local.scenario.init.sh $SCENARIO_NAME

# Startup WODA with WODA.2023 container and check that startup is done
banner "Startup WODA with WODA.2023 container and check that startup is done"
callRemote ./scenario.install.sh

# Restart once server
banner "Restart once server"
callRemote ./scenario.start.sh

# Check running servers
./local.scenario.test.sh $SCENARIO_NAME
