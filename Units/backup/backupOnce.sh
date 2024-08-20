#!/bin/bash

banner() {
  echo
  echo "============================================="
  echo $1
  echo "============================================="
}

# Work in build dir
mkdir -p _build
cd _build

# Initialization
date=$(date +%Y-%m-%d-%H_%M)
if [[ -n "${keyfile}" ]]; then
  echo "Use ${keyfile}"
  use_key="-i ${keyfile}"
fi

# Create sql.gz
banner "Get sql dumps"
ssh $use_key -o 'StrictHostKeyChecking no' WODA.test "pg_dump oncestore -h localhost -p 5433 -U once" | gzip > oncestore-db-${date}.sql.gz
ssh $use_key -o 'StrictHostKeyChecking no' WODA.test "pg_dump keycloak -h localhost -p 5439 -U keycloak" | gzip > keycloak-db-${date}.sql.gz

# Copy to backup server
banner "Copy to backup server"
# Postgres is now down
#rsync -avzP -e "ssh $use_key -o 'StrictHostKeyChecking no'" oncestore-db-${date}.sql.gz backup.sfsre.com:/var/backups/test.wo-da.de_once/
rsync -avzP -e "ssh $use_key -o 'StrictHostKeyChecking no'" keycloak-db-${date}.sql.gz backup.sfsre.com:/var/backups/test.wo-da.de_once/
