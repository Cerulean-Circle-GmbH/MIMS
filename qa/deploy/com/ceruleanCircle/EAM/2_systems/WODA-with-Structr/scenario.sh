#!/bin/bash

source .env

function banner() {
    echo
    echo "--- $1"
    echo
}

function checkURL() {
    up=$(curl -k -s -o /dev/null -w "%{http_code}" $1)
    if [ "$up" != "200" ]; then
        echo "ERROR: $1 is not running (returned $up) - $2"
    else
        echo "OK: running: $1 - $2"
    fi
}

function up() {
    # Create once-woda-network
    # TODO: Create once-woda-network and use in compose file
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
    banner "Create and run container"
    docker-compose -p $SCENARIO_NAME up -d
    docker ps

    # Test shell columns
    #banner "Test shell columns"
    #stty size | awk '{print $2}'
    #tput cols
    #shopt -s checkwinsize
    #echo COLUMNS=$COLUMNS

    # Wait for startup of container and installation of ONCE
    banner "Wait for startup of container and installation of ONCE"
    found=""
    echo
    echo
    echo
    echo
    echo
    echo
    while [ -z "$found" ]; do
    UP='\033[7A'
    LINEFEED='\033[0G'
    STR=$(docker logs -n 5 $SCENARIO_CONTAINER 2>&1)
    echo -e "$LINEFEED$UP"
    echo "== Wait for startup... ==========================================================="
    while IFS= read -r line
    do
        COLUMNS=80
        printf "\e[2m%-${COLUMNS}s\e[0m\n" "${line:0:${COLUMNS}}"
    done < <(printf '%s\n' "$STR")
    sleep 0.3
    found=$(docker logs $SCENARIO_CONTAINER 2>/dev/null | grep "Welcome to Web 4.0")
    done
    echo "===================="
    echo "Startup done ($found)"

    # Reconfigure ONCE server and connect structr
    banner "Reconfigure ONCE server and connect structr (in container $SCENARIO_CONTAINER)"
    docker exec -i $SCENARIO_CONTAINER bash -s << EOF
        source /root/.once
        export ONCE_REVERSE_PROXY_CONFIG='[["auth","test.wo-da.de"],["snet","test.wo-da.de"],["structr","$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTPS"]]'
        export ONCE_PROXY_HOST='0.0.0.0'
        export ONCE_STRUCTR_SERVER='https://localhost:5005'
        CF=\$ONCE_DEFAULT_SCENARIO/.once
        mv \$CF \$CF.ORIG
        cat \$CF.ORIG | sed "s;ONCE_REVERSE_PROXY_CONFIG=.*;ONCE_REVERSE_PROXY_CONFIG='\$ONCE_REVERSE_PROXY_CONFIG';" | sed "s;ONCE_PROXY_HOST=.*;ONCE_PROXY_HOST='\$ONCE_PROXY_HOST';" | sed "s;ONCE_STRUCTR_SERVER=.*;ONCE_STRUCTR_SERVER='\$ONCE_STRUCTR_SERVER';" > \$CF
        echo "CF=\$CF"
        cat \$CF | grep ONCE_REVERSE_PROXY_CONFIG
EOF

    # Checkout correct branch
    banner "Checkout correct branch (in container $SCENARIO_CONTAINER)"
    ENV_CONTENT=$(<$SCENARIOS_DIR/$SCENARIO_NAME/.env)
    docker exec -i $SCENARIO_CONTAINER bash -s << EOF
        cd /var/dev/EAMD.ucp
        git checkout $SCENARIO_BRANCH
        (
            date && echo
            git status && echo
            echo http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/
            echo http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/apps/neom/CityManagement.html
            echo https://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTPS/EAMD.ucp/
            echo http://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTP/structr/
            echo https://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTPS/structr/
            echo
            echo "$SCENARIOS_DIR/$SCENARIO_NAME/.env:"
            echo "$ENV_CONTENT"
            echo
            echo "/root/.once:"
            cat /root/.once
            echo
            . /root/.once
            echo "\$ONCE_DEFAULT_SCENARIO/.once:"
            cat \$ONCE_DEFAULT_SCENARIO/.once
        ) > ./installation-status.log
EOF

    private.restart.once
}

function start() {
    # Start container
    banner "Start container"
    docker-compose -p $SCENARIO_NAME start
    docker ps | grep $SCENARIO_NAME

    private.restart.once
}

function private.restart.once () {
    # Start ONCE server
    banner "Start ONCE server"
    docker exec $SCENARIO_CONTAINER bash -c "source ~/config/user.env && once restart"
    echo "ONCE server restarted"
}

function stop() {
    # Stop container
    banner "Stop container"
    docker-compose -p $SCENARIO_NAME stop
    docker ps | grep $SCENARIO_NAME
}

function down() {
    # Shutdown and remove containers
    banner "Shutdown and remove containers"
    docker-compose -p $SCENARIO_NAME down
    docker ps

    # Cleanup docker
    banner "Cleanup docker"
    docker volume rm ${SCENARIO_NAME}_var_dev
    docker volume ls
    docker image prune -f

    # Remove structr dir and other stuff
    rm -rf structr

    # Test
    banner "Test"
    docker volume ls | grep $SCENARIO_NAME
    tree -L 3 -a .
}

function test() {
    # Test
    banner "Test"
    docker volume ls | grep $SCENARIO_NAME
    docker ps | grep $SCENARIO_NAME
    tree -L 3 -a .

    # Check EAMD.ucp git status
    banner "Check EAMD.ucp git status for $SCENARIO_SERVER - $SCENARIO_NAME"
    curl http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/installation-status.log

    # Check running servers
    banner "Check running servers"
    checkURL http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/ "EAMD.ucp repository (http)"
    checkURL http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/installation-status.log "EAMD.ucp installation status"
    checkURL http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/apps/neom/CityManagement.html "NEOM CityManagement app"
    checkURL https://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTPS/EAMD.ucp/ "EAMD.ucp repository (https)"
    checkURL http://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTP/structr/ "structr server (http)"
    checkURL https://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTPS/structr/ "structr server (https)"
}

# Scenario vars
if [ -z "$1" ]; then
    echo "Usage: $0 (up,start,stop,down,test)"
    exit 1
fi

if [ $1 = "up" ]; then
    up
elif [ $1 = "start" ]; then
    start
elif [ $1 = "stop" ]; then
    stop
elif [ $1 = "down" ]; then
    down
elif [ $1 = "test" ]; then
    test
else
    echo "Usage: $0 (up,start,stop,down,test)"
    exit 1
fi