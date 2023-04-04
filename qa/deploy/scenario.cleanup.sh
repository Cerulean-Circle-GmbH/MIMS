#!/bin/bash

source .env

function banner() {
    echo
    echo "--- $1"
    echo
}

# Shutdown and remove containers
banner "Shutdown and remove containers"
docker-compose -p $SCENARIO_NAME down

# Cleanup docker
banner "Cleanup docker"
#docker volume rm ${SCENARIO_NAME}_var_dev
docker image prune -f

# Remove structr dir and other stuff
# MKT: TODO: Remove structr dir

# Test
banner "Test"
docker ps | grep $SCENARIO_NAME
docker volume ls | grep $SCENARIO_NAME
tree -L 3 -a .
