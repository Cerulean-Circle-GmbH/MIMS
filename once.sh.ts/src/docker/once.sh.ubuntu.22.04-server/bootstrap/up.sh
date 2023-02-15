#!/bin/bash

DOCKER_COMPOSE_FILE=$1
if [[ -z $DOCKER_COMPOSE_FILE || ! -f $DOCKER_COMPOSE_FILE ]]; then
    echo "$0 <docker-compose-file>"
else
    docker-compose -f $DOCKER_COMPOSE_FILE -p once up
fi