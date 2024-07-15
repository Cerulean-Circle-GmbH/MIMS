#!/bin/bash

source .env

function banner() {
    echo
    echo "--- $1"
    echo
}

function checkURL() {
    comment=$1
    shift
    echo
    echo call: curl -k -s -o /dev/null -w "%{http_code}" "$@"
    up=$(curl -k -s -o /dev/null -w "%{http_code}" "$@")
    if [[ "$up" != "200" && "$up" != "302" ]]; then
        echo "ERROR: $1 is not running (returned $up) - $comment"
    else
        echo "OK: running: $1 - $comment"
    fi
}

function up() {
    # Create jenkins image
    banner "Create jenkins image"
    docker build -t ${SCENARIO_DOCKER_IMAGENAME} .
    docker tag ${SCENARIO_DOCKER_IMAGENAME} ${SCENARIO_DOCKER_IMAGENAME}:${SCENARIO_DOCKER_IMAGEVERSION}
    docker tag ${SCENARIO_DOCKER_IMAGENAME} ${SCENARIO_DOCKER_IMAGENAME}:latest

    # Create and run container
    banner "Create and run container"
    docker-compose -p once up -d
    docker ps
}

function start() {
    # Start container
    banner "Start container"
    docker-compose -p once up -d
}

function stop() {
    # Stop container
    banner "Stop container"
    docker-compose -p once down
    docker ps | grep $SCENARIO_NAME
}

function down() {
    # Shutdown and remove containers
    banner "Shutdown and remove containers"
    docker-compose -p once down
    docker ps

    # Cleanup docker
    banner "Cleanup docker"
    docker image prune -f

    # Test
    banner "Test"
    tree -L 3 -a .
}

function test() {
    # Test
    banner "Test"
    echo "Volumes:"
    docker volume ls | grep $SCENARIO_NAME
    echo "Containers:"
    docker ps | grep $SCENARIO_NAME
    echo "Files:"
    pwd
    tree -L 3 -a .

    # Check EAMD.ucp git status
    banner "Check Jenkins $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
    checkURL "Jenkins (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_HTTPPORT/jenkins
}

# Scenario vars
if [ -z "$1" ]; then
    echo "Usage: $0 (up,start,stop,down,test)"
    exit 1
fi

if [ $1 = "up" ]; then
    up
elif [ $1 = "start" ]; then
    start
elif [ $1 = "stop" ]; then
    stop
elif [ $1 = "down" ]; then
    down
elif [ $1 = "test" ]; then
    test
else
    echo "Usage: $0 (up,start,stop,down,test)"
    exit 1
fi