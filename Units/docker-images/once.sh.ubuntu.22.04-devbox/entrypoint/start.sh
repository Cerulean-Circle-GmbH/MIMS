#!/bin/sh

# Checks if /nix/store is empty
if [ -z "$(ls -A /nix/store)" ]; then
  echo "Nix store volume is empty. Copying pre-filled store from image."
  cp -a /nix-store-backup/. /nix/store/
else
  echo "Nix store volume is not empty. Skipping copy."
fi

# Start docker-in-docker process
/usr/local/bin/start-docker.sh

# Start the normal container process
exec "$@"
