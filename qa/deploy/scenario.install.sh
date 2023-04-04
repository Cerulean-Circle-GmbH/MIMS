#!/bin/bash

source .env

function banner() {
    echo
    echo "--- $1"
    echo
}

# Create once-woda-network
# MKT: TODO: Create once-woda-network
#  NETWORK_NAME=once-woda-network
#  if [ -z $(docker network ls --filter name=^${NETWORK_NAME}$ --format="{{ .Name }}") ] ; then 
#      echo "${NETWORK_NAME} not exists, creating new..."
#      docker network create ${NETWORK_NAME} ; 
#      echo "${NETWORK_NAME} docker network created."
#      echo
#      docker network connect ${NETWORK_NAME} $(hostname)
#  else
#    echo "Docker Network '${NETWORK_NAME}' Already Exists..."
#  fi

pushd structr > /dev/null

# Keystore
banner "Keystore"
ln -s ../certbot/fullchain1.pem fullchain.pem
ln -s ../certbot/privkey1.pem privkey.pem
openssl pkcs12 -export -out keystore.pkcs12 -in fullchain.pem -inkey privkey.pem -password pass:qazwsx#123

# structr.zip
banner "structr.zip"
curl https://test.wo-da.de/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip -o ./structr.zip

popd > /dev/null

# Create structr image
banner "Create structr image"
docker-compose build
docker image ls

# Workspaces
#banner "Workspaces"
#curl https://test.wo-da.de/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/Workspaces.zip -o ./Workspaces.zip
#unzip -q ./Workspaces.zip

#banner "Show tree"
#tree -a .
#exit 0

# Create and run container
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