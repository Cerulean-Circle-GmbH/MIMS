#!/bin/bash

source .env
docker exec dev-once.sh_container bash -c "source ~/config/user.env && once restart"
echo "ONCE server restarted"
