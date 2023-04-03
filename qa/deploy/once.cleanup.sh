#!/bin/bash

source .env
docker-compose -p $SCENARIO_NAME down
docker volume rm ${SCENARIO_NAME}_var_dev
docker ps
docker volume ls
