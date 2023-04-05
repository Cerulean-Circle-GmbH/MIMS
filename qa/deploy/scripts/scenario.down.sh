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
docker ps

# Cleanup docker
banner "Cleanup docker"
docker volume rm ${SCENARIO_NAME}_var_dev
docker volume ls
docker image prune -f

# Remove structr dir and other stuff
rm -rf structr

# Test
banner "Test"
docker volume ls | grep $SCENARIO_NAME
tree -L 3 -a .
