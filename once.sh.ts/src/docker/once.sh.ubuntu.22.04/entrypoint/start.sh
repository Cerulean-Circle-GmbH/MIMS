#!/bin/bash

# The startup should not stop in case of error!
set +e

echo "Starting custom start script: $0"

# Start ssh
service ssh restart

# Start ONCE server
source ~/config/user.env
source ~/.once
once start

# Start
mkdir -p startmsg
echo "Welcome to Web 4.0" >startmsg/msg.txt
tail -f startmsg/msg.txt
