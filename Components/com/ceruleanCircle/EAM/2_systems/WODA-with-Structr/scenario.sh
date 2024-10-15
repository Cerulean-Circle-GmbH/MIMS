#!/usr/bin/env bash

# 'source' isn't available on all systems, so use . instead
. .env
. ./structr/.env
. deploy-tools.sh

# Set some variables
function setEnvironment() {
  deploy-tools.setEnvironment
}

function checkAndCreateDataVolume() {
  banner "Check data volume"
  deploy-tools.checkAndCreateDataVolume $SCENARIO_DATA_VOLUME "data-volume"
  deploy-tools.checkAndCreateDataVolume $SCENARIO_DATA_VOLUME1 "db-volume"
}

function recreateOnceCerts() {
  local certdir="$SCENARIO_SERVER_CERTIFICATEDIR"

  # Copy certificates to container
  if [ -n "$certdir" ] && [ "$certdir" != "none" ] && [ -f "$certdir/fullchain.pem" ] && [ -f "$certdir/privkey.pem" ]; then
    banner "Copy certificates to container"
    local CERT=$(cat $certdir/fullchain.pem)
    local KEY=$(cat $certdir/privkey.pem)
    DOCKEROUTPUT=$(
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
    )
    logVerbose "$DOCKEROUTPUT"
  fi
}

function up() {
  # Check data volume
  checkAndCreateDataVolume

  # Set environment
  setEnvironment

  mkdir -p structr/_data
  pushd structr/_data > /dev/null

  # If no certificate
  if [ "$SCENARIO_SERVER_CERTIFICATEDIR" != "none" ]; then
    deploy-tools.recreateKeystore "$SCENARIO_SERVER_CERTIFICATEDIR" "$CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR"
  else
    # TODO: Create a keystore if it does not exist and remove it from git
    mkdir -p $CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR/
    cp -f $CONFIG_DIR/structr/keystore.p12 $CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR/
  fi

  # TODO: Use default structr server if file is a server or none

  # TODO: --strip-components=1, fix in backup before
  deploy-tools.checkAndRestoreDataVolume $SCENARIO_DATA_RESTORESOURCE $SCENARIO_DATA_VOLUME 1
  deploy-tools.checkAndRestoreDataVolume $SCENARIO_SRC_STRUCTR_DATAFILE $SCENARIO_DATA_VOLUME1 1

  # Download structr.zip
  banner "Download structr.zip"
  deploy-tools.downloadFile https://test.wo-da.de/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip structr.zip
  popd > /dev/null

  # Create structr image
  banner "Create structr image"
  log "Building image..."
  # Only pull if image contains a "/" (means it's a repository)
  if [[ $SCENARIO_STRUCTR_IMAGE == *"/"* ]]; then
    docker pull ${SCENARIO_STRUCTR_IMAGE}
  fi
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS build > $VERBOSEPIPE
  docker image ls | grep $SCENARIO_STRUCTR_IMAGE > $VERBOSEPIPE

  # Create .gitconfig
  if [ $SCENARIO_SRC_ONCE_OUTERCONFIG != "none" ] && [ ! -f $SCENARIO_SRC_ONCE_OUTERCONFIG/.gitconfig ]; then
    mkdir -p $SCENARIO_SRC_ONCE_OUTERCONFIG
    NAME=$(ask_with_default "Your full name  (for Git) :" "")
    MAIL=$(ask_with_default "Your full email (for Git) :" "")
    # TODO: Check if gitconfig.template exists
    cat ../gitconfig.template | sed "s;##NAME##;$NAME;" | sed "s;##MAIL##;$MAIL;" > $SCENARIO_SRC_ONCE_OUTERCONFIG/.gitconfig
  fi

  # Create ssh keys
  if [ ! -f $SCENARIO_SRC_ONCE_OUTERCONFIG/.ssh/id_rsa ]; then
    mkdir -p $SCENARIO_SRC_ONCE_OUTERCONFIG/.ssh
    ssh-keygen -f $SCENARIO_SRC_ONCE_OUTERCONFIG/.ssh/id_rsa
  fi

  # Create and run container
  banner "Create and run container"
  # Only pull if image contains a "/" (means it's a repository)
  if [[ $SCENARIO_SRC_ONCE_IMAGE == *"/"* ]]; then
    docker pull ${SCENARIO_SRC_ONCE_IMAGE}
  fi
  docker-compose -p $SCENARIO_NAME $COMPOSE_FILE_ARGUMENTS up -d
  if [ "$VERBOSITY" == "-v" ]; then
    docker ps
  fi

  # Wait for startup of container and installation of ONCE
  banner "Wait for startup of container and installation of ONCE"
  local found=""
  log "Wait for startup of container..."
  log
  log
  log
  log
  log
  log
  while [ -z "$found" ]; do
    local UP='\033[7A'
    local LINEFEED='\033[0G'
    local STR=$(docker logs -n 5 $SCENARIO_ONCE_CONTAINER 2>&1)
    log -e "$LINEFEED$UP"
    log "== Wait for startup... ==========================================================="
    if [ "$VERBOSITY" != "-s" ]; then
      while IFS= read -r line; do
        local COLUMNS=80
        printf "\e[2m%-${COLUMNS}s\e[0m\n" "${line:0:${COLUMNS}}"
      done < <(printf '%s\n' "$STR")
    fi
    sleep 0.3
    found=$(docker logs $SCENARIO_ONCE_CONTAINER 2> /dev/null | grep "Welcome to Web 4.0")
  done
  logVerbose "===================="
  log "Startup done ($found)"

  recreateOnceCerts

  # Reconfigure ONCE server and connect structr
  banner "Reconfigure ONCE server and connect structr (in container $SCENARIO_ONCE_CONTAINER)"
  DOCKEROUTPUT=$(
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
  )
  logVerbose "$DOCKEROUTPUT"

  # Checkout correct branch
  if [ -n "$SCENARIO_SRC_ONCE_BRANCH" ] && [ "$SCENARIO_SRC_ONCE_BRANCH" != "none" ]; then
    banner "Checkout correct branch (in container $SCENARIO_ONCE_CONTAINER)"
    local ENV_CONTENT=$(< $CONFIG_DIR/.env)
    DOCKEROUTPUT=$(
      docker exec -i $SCENARIO_ONCE_CONTAINER bash -s << EOF
            cd /var/dev/EAMD.ucp
            git checkout $SCENARIO_SRC_ONCE_BRANCH > /dev/null 2>&1
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
                echo "$CONFIG_DIR/.env:"
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
    )
    logVerbose "$DOCKEROUTPUT"
  fi

  private.restart.once
}

function start() {
  # Check data volume
  checkAndCreateDataVolume

  # If no certificate
  if [ "$SCENARIO_SERVER_CERTIFICATEDIR" != "none" ]; then
    deploy-tools.recreateKeystore "$SCENARIO_SERVER_CERTIFICATEDIR" "$CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR"
  else
    # TODO: Create a keystore if it does not exist and remove it from git
    mkdir -p $CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR/
    cp -f $CONFIG_DIR/structr/keystore.p12 $CONFIG_DIR/$SCENARIO_STRUCTR_KEYSTORE_DIR/
  fi

  deploy-tools.start

  recreateOnceCerts
  private.restart.once
}

function private.restart.once() {
  # Start ONCE server
  banner "Start ONCE server"
  #docker exec $SCENARIO_ONCE_CONTAINER bash -c "source /root/.once && once restart"
  DOCKEROUTPUT=$(
    docker exec -i $SCENARIO_ONCE_CONTAINER bash -s << EOF
        cd /var/dev/EAMD.ucp
        source /root/.once
        once restart > /dev/null 2>&1
        sleep 5
        once cat > restart.log
EOF
  )
  logVerbose "$DOCKEROUTPUT"
  log "ONCE server restarted"
}

function stop() {
  # Check data volume
  checkAndCreateDataVolume

  deploy-tools.stop
}

function down() {
  # Check data volume
  checkAndCreateDataVolume

  deploy-tools.down

  # Remove structr data dir
  rm -rf structr/_data
}

function test() {
  # Check data volume
  checkAndCreateDataVolume

  # Set environment
  setEnvironment

  # Test
  # Print volumes, images, containers and files
  if [ "$VERBOSITY" == "-v" ]; then
    banner "Test"
    log "Volumes:"
    docker volume ls | grep ${SCENARIO_DATA_VOLUME}

    log "Images:"
    docker image ls | grep $(echo $SCENARIO_SRC_ONCE_IMAGE | sed "s;:.*;;")
    docker image ls | grep ${SCENARIO_STRUCTR_IMAGE}

    log "Containers:"
    docker ps | grep ${SCENARIO_ONCE_CONTAINER}
    docker ps | grep ${SCENARIO_STRUCTR_CONTAINER}
  fi

  # Check EAMD.ucp git status
  banner "Check EAMD.ucp git status for $SCENARIO_SERVER_NAME - $SCENARIO_NAME"
  if [ "$VERBOSITY" == "-v" ]; then
    curl http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTP/EAMD.ucp/installation-status.log
  fi

  # Check running servers
  banner "Check running servers"
  deploy-tools.checkURL "EAMD.ucp repository (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTP/EAMD.ucp/
  #deploy-tools.checkURL "EAMD.ucp installation status" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTP/EAMD.ucp/installation-status.log
  deploy-tools.checkURL "EAMD.ucp repository (https)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_HTTPS/EAMD.ucp/
  deploy-tools.checkURL "structr server (http)" http://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTP/structr/
  deploy-tools.checkURL "structr server (https)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTPS/structr/
  deploy-tools.checkURL "structr server (https) login" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_STRUCTR_HTTPS/structr/rest/login -XPOST -d '{ "name": "admin", "password": "*******" }'
  #deploy-tools.checkURL "structr server (https) login via reverse proxy (admin)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login -XPOST -d '{ "name": "admin", "password": "*******" }'
  #deploy-tools.checkURL "structr server (https) login via reverse proxy (NeomCityManager)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login -XPOST -d '{ "name": "NeomCityManager", "password": "secret" }'
  #deploy-tools.checkURL "structr server (https) login via reverse proxy (Visitor)" https://$SCENARIO_SERVER_NAME:$SCENARIO_RESOURCE_ONCE_REVERSEPROXY_HTTPS/structr/rest/login -XPOST -d '{ "name": "Visitor", "password": "secret" }'
}

function logs() {
  # Check data volume
  checkAndCreateDataVolume

  deploy-tools.logs
}

# Scenario vars
if [ -z "$1" ]; then
  deploy-tools.printUsage
  exit 1
fi

STEP=$1
shift

deploy-tools.parseArguments $@

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
elif [ $STEP = "logs" ]; then
  logs
else
  deploy-tools.printUsage
  exit 1
fi

exit $?
