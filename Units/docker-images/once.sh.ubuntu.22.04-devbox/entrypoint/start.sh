#!/bin/sh

# Checks if /nix/store is empty
if [ -z "$(ls -A /nix/store)" ]; then
  echo "Nix store volume is empty. Copying pre-filled store from image."
  cp -a /nix-store-backup/. /nix/store/
else
  echo "Nix store volume is not empty. Skipping copy."
fi

# Start docker-in-docker process
if [ -f "/etc/supervisor/conf.d/dockerd.conf" ]; then
  /usr/local/bin/start-docker.sh
fi

# Start the normal container process
exec "$@"
