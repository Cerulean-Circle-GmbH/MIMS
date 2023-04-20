#!/bin/bash

# TODO: Check variables (or prefill with default) that they exist and rewrite/update scenarios

source .env

function banner() {
    echo
    echo "--- $1"
    echo
}

function checkURL() {
    comment=$1
    shift
    echo
    echo call: curl -k -s -o /dev/null -w "%{http_code}" "$@"
    up=$(curl -k -s -o /dev/null -w "%{http_code}" "$@")
    if [ "$up" != "200" ]; then
        echo "ERROR: $1 is not running (returned $up) - $comment"
    else
        echo "OK: running: $1 - $comment"
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
        if [ -n "$SCENARIO_CERTIFICATE_DIR" ] && [ -f "$SCENARIO_CERTIFICATE_DIR/fullchain.pem" ] && [ -f "$SCENARIO_CERTIFICATE_DIR/privkey.pem" ]; then
            echo "Using certificates from $SCENARIO_CERTIFICATE_DIR"
            ls -l $SCENARIO_CERTIFICATE_DIR
            ln -s $SCENARIO_CERTIFICATE_DIR/fullchain.pem fullchain.pem
            ln -s $SCENARIO_CERTIFICATE_DIR/privkey.pem privkey.pem
            openssl x509 -noout -fingerprint -sha256 -inform pem -in fullchain.pem 
            openssl x509 -noout -fingerprint -sha1 -inform pem -in fullchain.pem 
            openssl x509 -noout -text -inform pem -in fullchain.pem 
        else
            # TODO: Check whether mkcert is installed and create certificates instead of copying
            #mkcert -cert-file fullchain.pem -key-file privkey.pem server.localhost localhost 127.0.0.1 ::1
            echo "Linking commited fullchain.pem and privkey.pem..."
            ln -s ../../certbot/fullchain.pem fullchain.pem
            ln -s ../../certbot/privkey.pem privkey.pem
        fi
        openssl pkcs12 -export -out keystore.pkcs12 -in fullchain.pem -inkey privkey.pem -password pass:qazwsx#123
    fi

    # Workspace
    banner "Workspace ($SCENARIO_STRUCTR_DATA_SRC_FILE)"
    if [ -d "WODA-current" ]; then
        echo "Already existing workspace..."
    else
        echo "Fetching workspace..."
        rsync -avzP -L -e "ssh -o StrictHostKeyChecking=no" $SCENARIO_STRUCTR_DATA_SRC_FILE WODA-current.tar.gz
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

    # TODO: Mount directory into container and let ONCE use it
    
    # Copy certificates to container
    if [ -n "$SCENARIO_CERTIFICATE_DIR" ]; then
        banner "Copy certificates to container"
        CERT=$(cat $SCENARIO_CERTIFICATE_DIR/fullchain.pem)
        KEY=$(cat $SCENARIO_CERTIFICATE_DIR/privkey.pem)
        docker exec -i $SCENARIO_CONTAINER bash -s << EOF
            source ~/config/user.env
            source ~/.once
            cd \$ONCE_DEFAULT_SCENARIO
            mv once.cert.pem once.cert.pem.bak
            mv once.key.pem once.key.pem.bak
            echo "$CERT" > once.cert.pem
            echo "$KEY" > once.key.pem
            ls once.*.pem
            openssl x509 -noout -fingerprint -sha256 -inform pem -in once.cert.pem 
            openssl x509 -noout -fingerprint -sha1 -inform pem -in once.cert.pem 
            openssl x509 -noout -text -inform pem -in once.cert.pem 
EOF
    fi

    # Reconfigure ONCE server and connect structr
    banner "Reconfigure ONCE server and connect structr (in container $SCENARIO_CONTAINER)"
    # TODO: Check this statement. The once docker container has dots in the name, but the structr container does not.
    # Docker container names must not contain dots
    DOCKER_STRUCTR_CONTAINER="$(echo ${SCENARIO_NAME}_woda-structr-server_1 | sed 's/\.//g' )"
    docker exec -i $SCENARIO_CONTAINER bash -s << EOF
        source /root/.once
        export ONCE_REVERSE_PROXY_CONFIG='[["auth","test.wo-da.de"],["snet","test.wo-da.de"],["structr","${DOCKER_STRUCTR_CONTAINER}:8083"]]'
        export ONCE_REV_PROXY_HOST='0.0.0.0'
        export ONCE_STRUCTR_SERVER='https://$SCENARIO_SERVER:$SCENARIO_ONCE_REVERSE_PROXY_HTTPS_PORT'
        CF=\$ONCE_DEFAULT_SCENARIO/.once
        mv \$CF \$CF.ORIG
        cat \$CF.ORIG | sed "s;ONCE_REVERSE_PROXY_CONFIG=.*;ONCE_REVERSE_PROXY_CONFIG='\$ONCE_REVERSE_PROXY_CONFIG';" | \
                        sed "s;ONCE_REV_PROXY_HOST=.*;ONCE_REV_PROXY_HOST='\$ONCE_REV_PROXY_HOST';" | \
                        sed "s;ONCE_STRUCTR_SERVER=.*;ONCE_STRUCTR_SERVER='\$ONCE_STRUCTR_SERVER';" > \$CF
        echo "CF=\$CF"
        cat \$CF | grep ONCE_REVERSE_PROXY_CONFIG
EOF

    # Checkout correct branch and add marker string to City Management App
    banner "Checkout correct branch (in container $SCENARIO_CONTAINER) and add marker string to City Management App (in container $SCENARIO_CONTAINER)"
    CMA_FILE="Components/com/neom/udxd/CityManagement/1.0.0/src/js/CityManagement.class.js"
    ENV_CONTENT=$(<$SCENARIOS_DIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME/.env)
    docker exec -i $SCENARIO_CONTAINER bash -s << EOF
        cd /var/dev/EAMD.ucp
        git checkout $CMA_FILE
        git checkout $SCENARIO_BRANCH
        git reset --hard
        git pull
        sed -i "s;City Management App;City Management App (scenario:$SCENARIO_NAME - branch:$SCENARIO_BRANCH - structr-tag:$SCENARIO_TAG - $(date));g" $CMA_FILE
        (
            date && echo
            git status && echo
            echo http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/
            echo http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/apps/neom/CityManagement.html
            echo https://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTPS/EAMD.ucp/
            echo http://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTP/structr/
            echo https://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTPS/structr/
            echo
            echo "$SCENARIOS_DIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME/.env:"
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
    checkURL "EAMD.ucp repository (http)" http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/
    checkURL "EAMD.ucp installation status" http://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTP/EAMD.ucp/installation-status.log
    checkURL "EAMD.ucp repository (https)" https://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTPS/EAMD.ucp/ 
    checkURL "NEOM CityManagement app" https://$SCENARIO_SERVER:$SCENARIO_ONCE_HTTPS/EAMD.ucp/apps/neom/CityManagement.html 
    checkURL "structr server (http)" http://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTP/structr/ 
    checkURL "structr server (https)" https://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTPS/structr/ 
    checkURL "structr server (https) login" https://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTPS/structr/rest/login  -XPOST -d '{ "name": "admin", "password": "*******" }'
    checkURL "structr server (https) login via reverse proxy (admin)" https://$SCENARIO_SERVER:$SCENARIO_ONCE_REVERSE_PROXY_HTTPS_PORT/structr/rest/login  -XPOST -d '{ "name": "admin", "password": "*******" }'
    checkURL "structr server (https) login via reverse proxy (NeomCityManager)" https://$SCENARIO_SERVER:$SCENARIO_ONCE_REVERSE_PROXY_HTTPS_PORT/structr/rest/login  -XPOST -d '{ "name": "NeomCityManager", "password": "secret" }'
    checkURL "structr server (https) login via reverse proxy (Visitor)" https://$SCENARIO_SERVER:$SCENARIO_ONCE_REVERSE_PROXY_HTTPS_PORT/structr/rest/login  -XPOST -d '{ "name": "Visitor", "password": "secret" }'

    # Why is this call failing from inside the Once container?
#    docker exec -i ${SCENARIO_NAME}_woda-structr-server_1 bash -s << EOF
#echo curl -k -s -o /dev/null -w %{http_code} https://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTPS/structr/rest/login -XPOST -d '{ "name": "admin", "password": "*******" }'
#curl -k -s -o /dev/null -w %{http_code} https://$SCENARIO_SERVER:$SCENARIO_STRUCTR_HTTPS/structr/rest/login -XPOST -d '{ "name": "admin", "password": "*******" }'
#EOF
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