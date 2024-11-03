## Start the container

To share the nix-store across containers or to persist the cached downloads, mount the volume nix-store:

```sh
docker build . -t once_devbox
docker run --rm -it -v nix-store:/nix once_devbox bash
```

For more options, look at the .devcontainer/docker-compose.yml.
