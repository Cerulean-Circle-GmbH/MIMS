#!/bin/bash

source .env

function banner() {
    echo
    echo "--- $1"
    echo
}

# Stop container
banner "Stop container"
docker-compose -p $SCENARIO_NAME stop
docker ps
