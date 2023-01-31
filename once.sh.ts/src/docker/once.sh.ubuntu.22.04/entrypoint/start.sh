#!/bin/bash

# The startup should not stop in case of error!
set +e

echo "Starting custom start script: $0"

# Start ssh
service ssh restart

# Start
cat startmsg/build.txt > startmsg/msg.txt
echo "Welcome to Web 4.0" >> startmsg/msg.txt
echo >> startmsg/msg.txt
echo "To start the ONCE server type:" >> startmsg/msg.txt
echo "   once restart" >> startmsg/msg.txt
echo "and then call: http://localhost:8080" >> startmsg/msg.txt
tail -f startmsg/msg.txt
