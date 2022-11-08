#!/bin/sh

echo "Starting custom start script: $0"
service ssh restart
mkdir -p startmsg
echo "Welcome to Web 4.0" >startmsg/msg.txt
tail -f startmsg/msg.txt
