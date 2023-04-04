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

mkdir -p structr/_data
pushd structr/_data > /dev/null

# Keystore
banner "Keystore"
if [ -f "keystore.pkcs12" ]; then
  echo "Already existing keystore.pkcs12..."
else
  echo "Creating new keystore.pkcs12..."
  ln -s ../../certbot/fullchain1.pem fullchain.pem
  ln -s ../../certbot/privkey1.pem privkey.pem
  openssl pkcs12 -export -out keystore.pkcs12 -in fullchain.pem -inkey privkey.pem -password pass:qazwsx#123
fi

# Workspace
banner "Workspace ($SCENARIO_STRUCTR_DATA_SRC_FILE)"
if [ -d "WODA-current" ]; then
  echo "Already existing workspace..."
else
  echo "Fetching workspace..."
  rsync -avzP -e "ssh -o StrictHostKeyChecking=no" $SCENARIO_STRUCTR_DATA_SRC_FILE WODA-current.tar.gz
  tar xzf WODA-current.tar.gz
fi

# structr.zip
banner "structr.zip"
if [ -f "structr.zip" ]; then
  echo "Already existing structr.zip..."
else
  echo "Fetching structr.zip..."
  curl https://test.wo-da.de/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip -o ./structr.zip
fi

popd > /dev/null

# Create structr image
banner "Create structr image"
docker-compose build
docker image ls

# Create and run container
docker-compose -p $SCENARIO_NAME up -d
docker ps

# Wait for startup of conainer and installation of ONCE
found=""
while [ -z "$found" ]; do
  # MKT: TODO: Fix this correctly
  echo "Waiting for startup..."
  sleep 1
  timeout 5s docker logs --follow $SCENARIO_CONTAINER
  found=$(docker logs $SCENARIO_CONTAINER 2>/dev/null | grep "Welcome to Web 4.0")
done
echo "Startup done ($found)"