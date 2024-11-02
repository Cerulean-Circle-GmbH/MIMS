# Use a build argument to specify the base image
ARG BASE_IMAGE=ubuntu:22.04
FROM ${BASE_IMAGE}

# Define environment variable
# ENV DEBUG ON
ENV WORKDIR=/workspace
ENV DEVBOX_USE_VERSION=0.13.5
ENV DEFAULT_TZ=Europe/Berlin

# Install additional OS packages
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive TZ=${DEFAULT_TZ} apt-get -y install --no-install-recommends \
  bash-completion \
  binutils \
  ca-certificates \
  curl \
  git \
  xz-utils \
  sudo \
  # Clean up
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install Nix package manager
RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux --init none --no-confirm
RUN echo "\n# Use devbox as global package manager\n" \
  'eval "$(devbox global shellenv --preserve-path-stack -r)" && hash -r' \
  >> ~/.bashrc
# Backup of the nix-store
RUN cp -a /nix/store /nix-store-backup

# Installing devbox
RUN curl -fsSL https://get.jetify.com/devbox | bash -s -- -f
RUN devbox version update

# Copy nushell config to home directory
COPY nushell/* /root/.config/nushell/

# TODO: Needs to be fixed in a better way (Understanding the real problem)
# Unset DISPLAY in vscodes .bashrc
RUN echo "unset DISPLAY" >> /root/.bashrc

WORKDIR /workspace

# Set start script as entrypoint
ADD entrypoint /entrypoint
RUN chmod +x /entrypoint/start.sh
ENTRYPOINT ["/entrypoint/start.sh"]

# use sh ant not bash, because bash will initialize devbox runtime
CMD ["sh"]
