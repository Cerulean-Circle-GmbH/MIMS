#!/bin/bash

# The startup should not stop in case of error!
set +e

echo "Starting custom start script: $0"

# Start ssh
service ssh restart

# Install buildx extension (calls docker, thatswhy necessary to call during runtime of container)
DOCKER_BUILDX_DIR=~/buildx
mkdir -p ${DOCKER_BUILDX_DIR}
pushd ${DOCKER_BUILDX_DIR}
DOCKER_BUILDKIT=1
docker build --platform=local -o . "https://github.com/docker/buildx.git"
mkdir -p ~/.docker/cli-plugins
mv buildx ~/.docker/cli-plugins/docker-buildx
popd

# Start
echo >> startmsg/msg.txt
cat startmsg/build.txt > startmsg/msg.txt
echo "Welcome to Web 4.0" >> startmsg/msg.txt
echo >> startmsg/msg.txt
tail -f startmsg/msg.txt
