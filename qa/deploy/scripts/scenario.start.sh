#!/bin/bash

source .env

function banner() {
    echo
    echo "--- $1"
    echo
}

# Restart once server
banner "Restart once server"
docker exec dev-once.sh_container bash -c "source ~/config/user.env && once restart"
echo "ONCE server restarted"
