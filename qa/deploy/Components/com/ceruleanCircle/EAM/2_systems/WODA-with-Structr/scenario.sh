#!/bin/bash

source .env

# Log verbose
function logVerbose() {
    # Check for verbosity not equal to -v
    if [ "$VERBOSITY" != "-v" ]; then
        return
    fi
    echo "$@"
}

# Log
function log() {
    if [ "$VERBOSITY" == "-s" ]; then
        return
    fi
    echo "$@"
}

# Banner
function banner() {
    logVerbose
    logVerbose "--- $1"
    logVerbose
}

function checkURL() {
    comment=$1
    shift
    logVerbose
    logVerbose call: curl -k -s -o /dev/null -w "%{http_code}" "$@"
    up=$(curl -k -s -o /dev/null -w "%{http_code}" "$@")
    if [ "$up" != "200" ]; then
        log "$1 is not running (returned $up) - $comment"
        return 1
    else
        log "OK: running: $1 - $comment"
        return 0
    fi
}

function up() {
    mkdir -p structr/_data
    pushd structr/_data > /dev/null

    local certdir=$SCENARIO_SERVER_CERTIFICATEDIR

    # Keystore
    banner "Keystore"
    if [ -f "keystore.pkcs12" ]; then
        logVerbose "Already existing keystore.pkcs12..."
    else
        logVerbose "Creating new keystore.pkcs12..."
        if [ -n "$certdir" ] && [ -f "$certdir/fullchain.pem" ] && [ -f "$certdir/privkey.pem" ]; then
            echo "Using certificates from $certdir"
            ls -l $certdir
            ln -s $certdir/fullchain.pem fullchain.pem
            ln -s $certdir/privkey.pem privkey.pem
            openssl x509 -noout -fingerprint -sha256 -inform pem -in fullchain.pem 
            openssl x509 -noout -fingerprint -sha1 -inform pem -in fullchain.pem 
            openssl x509 -noout -text -inform pem -in fullchain.pem 
        else
            # TODO: Check whether mkcert is installed and create certificates instead of copying
            #mkcert -cert-file fullchain.pem -key-file privkey.pem server.localhost localhost 127.0.0.1 ::1
            logVerbose "Linking commited fullchain.pem and privkey.pem..."
            ln -s ../../certbot/fullchain.pem fullchain.pem
            ln -s ../../certbot/privkey.pem privkey.pem
        fi
        openssl pkcs12 -export -out keystore.pkcs12 -in fullchain.pem -inkey privkey.pem -password pass:qazwsx#123
    fi

    # Workspace
    banner "Workspace ($SCENARIO_SRC_STRUCTRDATAFILE)"
    if [ -d "WODA-current" ]; then
        logVerbose "Already existing workspace..."
    else
        logVerbose "Fetching workspace..."
        if [ "$VERBOSITY" == "-v" ]; then
            RSYNC_VERBOSE="-v"
        fi
        rsync -azP $RSYNC_VERBOSE -L -e "ssh -o StrictHostKeyChecking=no" $SCENARIO_SRC_STRUCTRDATAFILE WODA-current.tar.gz
        tar xzf WODA-current.tar.gz
    fi

    # structr.zip
    banner "structr.zip"
    if [ -f "structr.zip" ]; then
        logVerbose "Already existing structr.zip..."
    else
        logVerbose "Fetching structr.zip..."
        curl https://test.wo-da.de/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip -o ./structr.zip
    fi

    popd > /dev/null

    # Create structr image
    banner "Create structr image"
    log "Building image..."
    if [ "$VERBOSITY" == "-v" ]; then
        docker-compose build
        docker image ls
    else
        docker-compose build > /dev/null
    fi

    # Create and run container
    banner "Create and run container"
    docker-compose -p $SCENARIO_NAME up -d
    if [ "$VERBOSITY" == "-v" ]; then
        docker ps
    fi

    # Wait for startup of container and installation of ONCE
    banner "Wait for startup of container and installation of ONCE"
    local found=""
    logVerbose "Wait for startup of container..."
    logVerbose
    logVerbose
    logVerbose
    logVerbose
    logVerbose
    logVerbose
    while [ -z "$found" ]; do
        local UP='\033[7A'
        local LINEFEED='\033[0G'
        local STR=$(docker logs -n 5 $SCENARIO_ONCE_CONTAINER 2>&1)
        logVerbose -e "$LINEFEED$UP"
        logVerbose "== Wait for startup... ==========================================================="
        if [ "$VERBOSITY" == "-v" ]; then
            while IFS= read -r line
            do
                local COLUMNS=80
                printf "\e[2m%-${COLUMNS}s\e[0m\n" "${line:0:${COLUMNS}}"
            done < <(printf '%s\n' "$STR")
        fi
        sleep 0.3
        found=$(docker logs $SCENARIO_ONCE_CONTAINER 2>/dev/null | grep "Welcome to Web 4.0")
    done
    logVerbose "===================="
    log "Startup done ($found)"

    # TODO: Mount directory into container and let ONCE use it
    
    # Copy certificates to container
    if [ -n "$certdir" ] && [ -f "$certdir/fullchain.pem" ] && [ -f "$certdir/privkey.pem" ]; then
        banner "Copy certificates to container"
        local CERT=$(cat $certdir/fullchain.pem)
        local KEY=$(cat $certdir/privkey.pem)
        docker exec -i $SCENARIO_ONCE_CONTAINER bash -s << EOF
            source /root/.once
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
    banner "Reconfigure ONCE server and connect structr (in container $SCENARIO_ONCE_CONTAINER)"
    docker exec -i $SCENARIO_ONCE_CONTAINER bash -s << EOF
        source /root/.once
        export ONCE_REVERSE_PROXY_CONFIG='[["auth","test.wo-da.de"],["snet","test.wo-da.de"],["structr","${SCENARIO_STRUCTR_CONTAINER}:8083"]]'
        export ONCE_REV_PROXY_HOST='0.0.0.0'
        export ONCE_STRUCTR_SERVER='https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS'
        CF=\$ONCE_DEFAULT_SCENARIO/.once
        mv \$CF \$CF.ORIG
        cat \$CF.ORIG | sed "s;ONCE_REVERSE_PROXY_CONFIG=.*;ONCE_REVERSE_PROXY_CONFIG='\$ONCE_REVERSE_PROXY_CONFIG';" | \
                        sed "s;ONCE_REV_PROXY_HOST=.*;ONCE_REV_PROXY_HOST='\$ONCE_REV_PROXY_HOST';" | \
                        sed "s;ONCE_STRUCTR_SERVER=.*;ONCE_STRUCTR_SERVER='\$ONCE_STRUCTR_SERVER';" > \$CF
        echo "CF=\$CF"
        cat \$CF | grep ONCE_REVERSE_PROXY_CONFIG
EOF

    # Checkout correct branch
    banner "Checkout correct branch (in container $SCENARIO_ONCE_CONTAINER)"
    local ENV_CONTENT=$(<$SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME/.env)
    docker exec -i $SCENARIO_ONCE_CONTAINER bash -s << EOF
        cd /var/dev/EAMD.ucp
        git checkout $SCENARIO_SRC_BRANCH
        git reset --hard
        git pull
        (
            date && echo
            git status && echo
            echo http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTP/EAMD.ucp/
            echo http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTP/EAMD.ucp/apps/neom/CityManagement.html
            echo https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTPS/EAMD.ucp/
            echo http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTP/structr/
            echo https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTPS/structr/
            echo
            echo "$SCENARIO_SERVER_CONFIGSDIR/$SCENARIO_NAME_SPACE/$SCENARIO_NAME/.env:"
            echo "$ENV_CONTENT"
            echo
            echo "/root/.once:"
            cat /root/.once
            echo
            source /root/.once
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
    if [ "$VERBOSITY" == "-v" ]; then
        docker ps | grep $SCENARIO_NAME
    fi

    private.restart.once
}

function private.restart.once () {
    # Start ONCE server
    banner "Start ONCE server"
    #docker exec $SCENARIO_ONCE_CONTAINER bash -c "source /root/.once && once restart"
    docker exec -i $SCENARIO_ONCE_CONTAINER bash -s << EOF
cd /var/dev/EAMD.ucp
source /root/.once
once restart
sleep 5
once cat > restart.log
EOF
    log "ONCE server restarted"
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
    if [ "$VERBOSITY" == "-v" ]; then
        docker ps
    fi

    # Cleanup docker
    banner "Cleanup docker"
    docker volume rm ${SCENARIO_NAME}_var_dev
    if [ "$VERBOSITY" == "-v" ]; then
        docker volume ls
    fi
    docker image prune -f

    # Remove structr dir and other stuff
    rm -rf structr

    # Test
    banner "Test"
    if [ "$VERBOSITY" == "-v" ]; then
        docker volume ls | grep $SCENARIO_NAME
        tree -L 3 -a .
    fi
}

function test() {
    # Test
    # Print volumes, images, containers and files
    if [ "$VERBOSITY" == "-v" ]; then
        banner "Test"
        log "Volumes:"
        docker volume ls | grep $SCENARIO_NAME
        log "Images:"
        docker image ls | grep $SCENARIO_NAME
        log "Containers:"
        docker ps -all | grep $SCENARIO_NAME
        tree -L 3 -a .
    fi

    # Check EAMD.ucp git status
    banner "Check EAMD.ucp git status for $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
    curl http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTP/EAMD.ucp/installation-status.log

    # Check running servers
    banner "Check running servers"
    checkURL "EAMD.ucp repository (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTP/EAMD.ucp/
    checkURL "EAMD.ucp installation status" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTP/EAMD.ucp/installation-status.log
    checkURL "EAMD.ucp repository (https)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTPS/EAMD.ucp/ 
    checkURL "NEOM CityManagement app" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTPS/EAMD.ucp/apps/neom/CityManagement.html 
    checkURL "structr server (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTP/structr/ 
    checkURL "structr server (https)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTPS/structr/ 
    checkURL "structr server (https) login" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTPS/structr/rest/login  -XPOST -d '{ "name": "admin", "password": "*******" }'
    checkURL "structr server (https) login via reverse proxy (admin)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login  -XPOST -d '{ "name": "admin", "password": "*******" }'
    checkURL "structr server (https) login via reverse proxy (NeomCityManager)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login  -XPOST -d '{ "name": "NeomCityManager", "password": "secret" }'
    checkURL "structr server (https) login via reverse proxy (Visitor)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login  -XPOST -d '{ "name": "Visitor", "password": "secret" }'
}

function printUsage() {
    log "Usage: $0 (up,start,stop,down,test)  [-v|-s|-h]"
    exit 1
}

# Scenario vars
if [ -z "$1" ]; then
    printUsage
    exit 1
fi

STEP=$1
shift

# Parse all "-" args
for i in "$@"
do
case $i in
    -v|--verbose)
    VERBOSITY=$i
    ;;
    -s|--silent)
    VERBOSITY=$i
    ;;
    -h|--help)
    HELP=true
    ;;
    *)
    # unknown option
    log "Unknown option: $i"
    printUsage
    ;;
esac
done

# Print help
if [ "$HELP" = true ]; then
    printUsage
fi

if [ $STEP = "up" ]; then
    up
elif [ $STEP = "start" ]; then
    start
elif [ $STEP = "stop" ]; then
    stop
elif [ $STEP = "down" ]; then
    down
elif [ $STEP = "test" ]; then
    test
else
    printUsage
    exit 1
fi

exit $?
