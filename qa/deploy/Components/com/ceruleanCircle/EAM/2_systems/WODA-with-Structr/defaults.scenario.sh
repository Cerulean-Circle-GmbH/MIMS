## Source setup
# Which backup tag should be restored?
SCENARIO_TAG=latest
# Which ONCE branch should be restored (maybe tag dependent)?
SCENARIO_BRANCH=dev/neom
# What is the URI of the struct data backup file (maybe tag dependent)?
SCENARIO_STRUCTR_DATA_SRC_FILE=backup.sfsre.com:/var/backups/structr/backup-structr-${SCENARIO_TAG}_WODA-current.tar.gz
# What is the name of the scenario component (including namespace)?
SCENARIO_COMPONENT_DIR=com/ceruleanCircle/EAM/2_systems/WODA-with-Structr

## Server setup
# What is the server, the scenario will be deployed?
SCENARIO_SERVER=test.wo-da.de
# What is the SSH config the server can be connected with?
SCENARIO_SSH_CONFIG=WODA.test
# What is the scenarios root directory on the server?
SCENARIOS_DIR=/var/dev/ONCE.2023-Scenarios
# Where to find the servers certificate?
SCENARIO_CERTIFICATE_DIR=/var/dev/EAMD.ucp/Scenarios/de/1blu/v36421/vhosts/de/wo-da/test/EAM/1_infrastructure/Docker/CertBot.v1.7.0/config/conf/live/test.wo-da.de

## Unique resources
# What is the container name for the ONCE service?
SCENARIO_CONTAINER=${SCENARIO_NAME}-once.sh_container
# What is the ONCE http port?
SCENARIO_ONCE_HTTP=9380
# What is the ONCE https port?
SCENARIO_ONCE_HTTPS=9743
# What is the ONCE container SSH port?
SCENARIO_ONCE_SSH=9322
# What is the ONCE domain?
SCENARIO_DOMAIN=localhost
# What is the STRUCTR http port?
SCENARIO_STRUCTR_HTTP=9382
# What is the STRUCTR https port?
SCENARIO_STRUCTR_HTTPS=9383
# What is the ONCE reverse proxy http port?
SCENARIO_ONCE_REVERSE_PROXY_HTTP_PORT=6302
# What is the ONCE reverse proxy https port?
SCENARIO_ONCE_REVERSE_PROXY_HTTPS_PORT=6305
