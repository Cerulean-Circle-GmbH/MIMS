#!/bin/bash

source .env

function banner() {
    echo
    echo "--- $1"
    echo
}

# Start container
banner "Start container"
docker-compose -p $SCENARIO_NAME start
docker ps | grep $SCENARIO_NAME

# Restart once server
banner "Restart once server"
docker exec dev-once.sh_container bash -c "source ~/config/user.env && once restart"
echo "ONCE server restarted"
