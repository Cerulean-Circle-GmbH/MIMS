#!/bin/bash

source .env
cat .env
docker-compose -p $SCENARIO_NAME up -d
docker ps

# Wait for startup of conainer and installation of ONCE
found=""
while [ -z "$found" ]; do
  echo "Waiting for startup..."
  sleep 1
  timeout 5s docker logs --follow $SCENARIO_CONTAINER
  found=$(docker logs $SCENARIO_CONTAINER 2>/dev/null | grep "Welcome to Web 4.0")
done
echo "Startup done ($found)"