#!/bin/bash


#
# ONCE
#

function private.docker.scenario.create.structr() #
{
    private.docker.scenario.delete.structr

  NETWORK_NAME=once-woda-network
  if [ -z $(docker network ls --filter name=^${NETWORK_NAME}$ --format="{{ .Name }}") ] ; then 
      echo "${NETWORK_NAME} not exists, creating new..."
      docker network create ${NETWORK_NAME} ; 
      echo "${NETWORK_NAME} docker network created."
      echo
      docker network connect ${NETWORK_NAME} $(hostname)
  else
    echo "Docker Network '${NETWORK_NAME}' Already Exists..."
  fi

  local domain="$ONCE_SCENARIO_DOMAIN"
  if [ -z "$domain" ]; then
    error.log "Domain Name Missing in the command.";
    warn.log "Using domain: $domain"
    return 2
    #exit;
  fi

  cp /var/dev/EAMD.ucp/3rdPartyComponents/org/structr/StructrServer/2.1.4/src/start-structr.sh .
  #wget https://test.wo-da.de/EAMD.ucp/Components/com/ceruleanCircle/EAM/1_infrastructure/DockerWorkspaces/WODA/1.0.0/Alpine/3.13.2/Openjdk/8/Structr/2.1.4/src/start-structr.sh
  chmod +x ./start-structr.sh

  cp /var/dev/EAMD.ucp/3rdPartyComponents/org/structr/StructrServer/2.1.4/src/templates/structr.conf .
  #wget https://test.wo-da.de/EAMD.ucp/Components/com/ceruleanCircle/EAM/1_infrastructure/DockerWorkspaces/WODA/1.0.0/Alpine/3.13.2/Openjdk/8/Structr/2.1.4/src/structr.conf
  chmod 777 ./structr.conf
    
  once.scenario.map certbot
  CERTBOT_SCENARIO=$SELECTED_SCENARIO

  once.scenario.map structr
  structr_SCENARIO=$SELECTED_SCENARIO
    
    echo "Creating .env file for  structr"

    {
      echo "defaultWorkspace=/EAMD.ucp"
      echo "defaultServer=https://$domain"
      echo "structr_dir=./Workspaces/structrAppWorkspace/WODA-current"
      echo "files_dir=/EAMD.ucp"
      echo "UID=0"
      echo "GID=33"
    }>> .env

    # echo $ONCE_SCENARIO/EAM/1_infrastructure/Docker/CertBot/1.7.0/config/conf/archive/$1/

    if [ -f "keystore.pkcs12" ]; then
      echo "Removing old keystore.pkcs12...";
      rm keystore.pkcs12
      # if [ -f "./fullchain.pem" ]; then
        echo "Coping fullchain.pem file...."
        ln -s $ONCE_DEFAULT_SCENARIO/once.fullchain.pem ./fullchain.pem
      # fi

      # if [ -f "./private.pem" ]; then
        echo "Coping private.pem file...."
        ln -s $ONCE_DEFAULT_SCENARIO/once.key.pem ./privkey.pem
      # fi

      echo "Creating New keystore.pkcs12...."      
      openssl pkcs12 -export -out keystore.pkcs12 -in fullchain.pem -inkey privkey.pem -password pass:qazwsx#123

      if [ -f "keystore.pkcs12" ]; then
        echo "File keystore.pkcs12 created successfully...."
      else
        echo "something went work while creating please try again & check file location...";
        exit
      fi
    else
      # if [ -f "./fullchain.pem" ]; then
        echo "Coping fullchain.pem file...."
        rm ./fullchain.pem
        ln -s $ONCE_SCENARIO$CERTBOT_SCENARIO/config/conf/live/$domain/fullchain.pem ./fullchain.pem
        
      # fi

      # if [ -f "./private.pem" ]; then
        echo "Coping private.pem file...."
        rm ./privkey.pem
        ln -s $ONCE_SCENARIO$CERTBOT_SCENARIO/config/conf/live/$domain/privkey.pem ./privkey.pem
      # fi

      echo "Creating New keystore.pkcs12...."      
      openssl pkcs12 -export -out keystore.pkcs12 -in fullchain.pem -inkey privkey.pem -password pass:qazwsx#123

      if [ -f "keystore.pkcs12" ]; then
        echo "File keystore.pkcs12 created successfully...."
      else
        echo "something went work while creating please try again & check file location...";
        exit
      fi
    fi
    if [ ! -d "./Workspaces" ]; then    
        echo "Creating Workspace Directory......."
        # cd $ONCE_REPO_PREFIX/
        if [ ! -f "$ONCE_REPO_PREFIX/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/Workspaces.zip" ]; then
          wget https://test.wo-da.de/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/Workspaces.zip
          unzip -q ./Workspaces.zip
        else 
          unzip  -q $ONCE_REPO_PREFIX/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/Workspaces.zip
        fi
        
    fi    
    if [ ! -f "structr.zip" ]; then    
      if [ ! -f $ONCE_REPO_PREFIX/EAMD.ucp/Components/com/ceruleanCircle/EAM/1_infrastructure/DockerWorkspaces/WODA/1.0.0/Alpine/3.13.2/Openjdk/8/Structr/2.1.4/src/structr.zip ]; then
          echo "Coping structr.zip files...."
          cp $ONCE_REPO_PREFIX/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip ./
      else
        wget https://test.wo-da.de/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip
      fi
    fi
    
    echo "Creating Dockerfile file"
    {
      echo "FROM openjdk:8-jdk-alpine"

      echo "#ARG STRUCTR_VERSION"
      echo "ARG JAVA_OPT_XMS=4"
      echo "ARG JAVA_OPT_XMX=4"

      echo "ARG UID=\${UID}"
      echo "ARG GID=\${GID}"
      echo "USER \${UID}:\${GID}"
      
      echo "ENV JAVA_OPT_XMS=\$JAVA_OPT_XMS"
      echo "ENV JAVA_OPT_XMX=\$JAVA_OPT_XMX"

      echo "#ENV defaultServer \$defaultServer"

      echo "ENV WORK_DIR /var/lib/structr"

      echo 'ENV PATH="${PATH}:${WORK_DIR}/scripts"'


      echo 'ENV TERM="xterm"'

      echo 'ENV defaultServer="${defaultServer}"'

      echo "RUN apk add unzip git tree ncurses openssh-client bash curl wget"
      echo "RUN mkdir \${WORK_DIR}"
      echo "WORKDIR \${WORK_DIR}"
      echo "ADD structr.zip /"
      echo "RUN unzip -q /structr.zip -d /var/lib && rm /structr.zip"
      echo "ADD structr.conf \${WORK_DIR}/"
      echo "ADD keystore.pkcs12 \${WORK_DIR}/"
      echo "RUN mkdir /usr/lib/structr"
      echo "ADD keystore.pkcs12 /usr/lib/structr/"
      echo "ADD start-structr.sh \${WORK_DIR}/bin"

      
      echo 'ENTRYPOINT [ "bin/start-structr.sh" ]'
      

    } >> Dockerfile
    echo 
    warn.log "Structr Dockefile file created..."
    cat Dockerfile
    echo 
    
    {
      echo "version: '3'"

      echo "services:"
      echo "  $SELECTED_SCENARIO_NAME-service:"
      echo "    build: './'"
      echo "    container_name: $SELECTED_SCENARIO_DC_NAME"
      echo "    image: $SELECTED_SCENARIO_DI_NAME"
      echo '    user: "${UID}:${GID}"'
      echo "    restart: unless-stopped"
      echo "    env_file: '.env'"
      echo "    ports:"
      echo "      - 8082:8082"
      echo "      - 8083:8083"
      echo "      - 8021:8021"
      echo "      - 7574:7688"
      echo "    volumes:"
      echo "      - \${structr_dir}/db/:/var/lib/structr/db/"
      echo "      - \${structr_dir}/files/:/var/lib/structr/files/"
      echo "      - \${structr_dir}/layouts/:/var/lib/structr/layouts/"
      echo "      - \${structr_dir}/logs/:/var/lib/structr/logs/"
      echo "      - \${structr_dir}/sessions/:/var/lib/structr/sessions/"
      echo "      - \${structr_dir}/snapshots/:/var/lib/structr/snapshots/"
      echo "      - \${files_dir}:/EAMD.ucp"
      echo "      - \${files_dir}/Components/tla/EAMD/UcpComponentSupport/1.0.0/src/sh:/var/lib/structr/scripts/"
      echo "    environment:"
      echo "      - PROXY_ADDRESS_FORWARDING=true"
      
      echo "networks:"
      echo "  default:"
      echo "    external:"
      echo "      name: once-woda-network"

    } >> docker-compose.yml

    echo 
    warn.log "docker-compose.yml file created..."
    cat docker-compose.yml
    echo

}

once.structr.start() { # #
  cd $ONCE_REPO_PREFIX/EAMD.ucp/3rdPartyComponents/org/structr/StructrServer/woda2.local/docker/local/structr/1.0.0
  runDocker
}
once.structr.stop() { # #
  cd $ONCE_REPO_PREFIX/EAMD.ucp/3rdPartyComponents/org/structr/StructrServer/woda2.local/docker/local/structr/1.0.0
  docker-compose down
}

#
# runDocker
#

echo 
echo "Structr Server Docker Image"
echo "============================================================"
echo
if [ ! -d "/var/dev/Workspaces" ]; then    
    echo "Creating Workspace Directory......."
    cd /var/dev/
    unzip  -q /var/dev/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/Workspaces.zip
fi    
if [ ! -e /var/dev/EAMD.ucp/Components/com/ceruleanCircle/EAM/1_infrastructure/DockerWorkspaces/WODA/1.0.0/Alpine/3.13.2/Openjdk/8/Structr/2.1.4/src/structr.zip ]; then
    echo "Coping structr.zip files...."
    cp /var/dev/EAMD.ucp/Components/org/structr/StructrServer/2.1.4/dist/structr.zip /var/dev/EAMD.ucp/Components/com/ceruleanCircle/EAM/1_infrastructure/DockerWorkspaces/WODA/1.0.0/Alpine/3.13.2/Openjdk/8/Structr/2.1.4/src/
fi
cd /var/dev/EAMD.ucp/Components/com/ceruleanCircle/EAM/1_infrastructure/DockerWorkspaces/WODA/1.0.0/Alpine/3.13.2/Nginx/1.15/certbot/1.7.0/test.wo-da.de/
docker-compose build


now=$(date)
echo "Start At: $now"
echo "Checking Docker Image Status....."
echo
cd /var/dev/EAMD.ucp/Components/com/ceruleanCircle/EAM/1_infrastructure/DockerWorkspaces/WODA/1.0.0/Alpine/3.13.2/Openjdk/8/Structr/2.1.4/
#check docker woda application with nodejs service status
docker-compose ps --services --filter "status=running" | grep woda-structr-server
export status=$?
if [ $status = 0 ]; then
    echo "Container Already Runing...";    
    echo "Terminating Your Command...."
else
    echo "Conatiner not runing..."; 
    echo
    echo "Building Structr Server Docker Image..."
    echo
    cd /var/dev/EAMD.ucp/Components/com/ceruleanCircle/EAM/1_infrastructure/DockerWorkspaces/WODA/1.0.0/Alpine/3.13.2/Openjdk/8/Structr/2.1.4/
    docker-compose up
fi
echo "============================================================"