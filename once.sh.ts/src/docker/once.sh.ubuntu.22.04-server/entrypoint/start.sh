#!/bin/bash

# The startup should not stop in case of error!
set +e

echo "Starting custom start script: $0"
cat ~/startmsg/build.txt > ~/startmsg/msg.txt
echo >> ~/startmsg/msg.txt
echo "Timing:" >> ~/startmsg/msg.txt
echo "start.sh:$LINENO: $(date)" >> ~/startmsg/msg.txt

# Start ssh
service ssh restart
echo "start.sh:$LINENO: $(date) ssh restarted" >> ~/startmsg/msg.txt

# Install once (only if it is not yet initialized)
source ~/config/user.env
~/entrypoint/install-once.sh
echo "start.sh:$LINENO: $(date) ONCE installed" >> ~/startmsg/msg.txt

# Setup Git configuration and SSH keys as new id in .ssh/ids
~/entrypoint/install-git-ssh-config.sh
echo "start.sh:$LINENO: $(date) config integrated" >> ~/startmsg/msg.txt

# Start
echo >> ~/startmsg/msg.txt

echo "Welcome to Web 4.0" >> ~/startmsg/msg.txt
echo >> ~/startmsg/msg.txt
echo "To start the ONCE server type:" >> ~/startmsg/msg.txt
echo "   once restart" >> ~/startmsg/msg.txt
if [ -z "$ONCE_DOCKER_HTTP_PORT" ]; then
    export ONCE_DOCKER_HTTP_PORT=8080
    export ONCE_DOCKER_HTTPS_PORT=8443
fi
echo "and then call: http://localhost:${ONCE_DOCKER_HTTP_PORT} or https://localhost:${ONCE_DOCKER_HTTPS_PORT}" >> ~/startmsg/msg.txt
tail -n 20 -f ~/startmsg/msg.txt
