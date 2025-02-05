# Use a build argument to specify the base image
ARG BASE_IMAGE=ubuntu:22.04
FROM ${BASE_IMAGE}

# Define environment variable
# ENV DEBUG ON
ENV WORKDIR=/workspace
ENV DEVBOX_USE_VERSION=0.13.7
ENV DEFAULT_TZ=Europe/Berlin

# Install additional OS packages
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive TZ=${DEFAULT_TZ} apt-get -y install --no-install-recommends \
  bash-completion \
  binutils \
  ca-certificates \
  curl \
  errno \
  git \
  net-tools \
  sudo \
  tzdata \
  wget \
  xz-utils \
  # Clean up
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install Nix package manager
RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux --init none --no-confirm
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

# Install OOSH from entrypoint scripts
ADD entrypoint /entrypoint
RUN chmod +x /entrypoint/install-oosh.sh
RUN /entrypoint/install-oosh.sh

# Set start script as entrypoint
RUN chmod +x /entrypoint/start.sh
ENTRYPOINT ["/entrypoint/start.sh"]

# Set devbox as global package manager - Must be set after OOSH installation!
RUN echo "\n# Use devbox as global package manager\n" \
  'eval "$(devbox global shellenv --preserve-path-stack -r)" && hash -r' \
  >> ~/.bashrc
COPY devbox.json /root/.local/share/devbox/global/default/devbox.json
COPY devbox.lock /root/.local/share/devbox/global/default/devbox.lock

# Patch PATH for OOSH including devbox
RUN sed -i 's|^export PATH=.*|export PATH="/root/.local/share/devbox/global/default/.devbox/nix/profile/default/bin:/root/oosh/su:/root/oosh/ng:/root/oosh:/root/oosh/init:/root/oosh/external:/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/root/.local/share/devbox/global/default/.devbox/virtenv/runx/bin"|' ~/config/user.env

# Install yq yaml parser manually, because devbox has some issues with that
RUN curl -fsSL https://github.com/mikefarah/yq/releases/download/v4.44.5/yq_linux_amd64.tar.gz | \
  tar xz && mv yq_linux_amd64 /usr/local/bin/yq

# use sh ant not bash, because bash will initialize devbox runtime
CMD ["sh"]
