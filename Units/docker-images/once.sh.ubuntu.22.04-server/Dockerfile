# Use an official Python runtime as a parent image
# TODO: ubuntu:latest doesn't work on arm64 platform with DOCKER_BUILDKIT. Why?
#FROM ubuntu:latest
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND noninteractive
ENV WORKDIR /root/
WORKDIR $WORKDIR
RUN export PATH=.:$PATH

# Pre-install various packages to speedup startup
RUN apt update && apt install wget curl rsync openssh-server -y
RUN apt update && apt install net-tools errno gnupg -y
RUN apt update && apt install plantuml -y
RUN apt update && apt install docker.io docker-compose -y

# Fix nodejs problem on ubuntu
# (See https://github.com/nodesource/distributions/issues/1157#issuecomment-1131212089)
RUN dpkg --remove --force-remove-reinstreq libnode-dev
RUN dpkg --remove --force-remove-reinstreq libnode72:amd64
RUN dpkg --remove --force-remove-reinstreq libnode72:arm64

# Install yq yaml parser
RUN curl -fsSL https://github.com/mikefarah/yq/releases/download/v4.44.5/yq_linux_amd64.tar.gz | \
    tar xz && mv yq_linux_amd64 /usr/local/bin/yq

# Install jq json parser
RUN curl -fsSLO https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64 && \
    mv jq-linux-amd64 /usr/local/bin/jq && chmod 755 /usr/local/bin/jq

# build all things inside container
ADD entrypoint entrypoint
RUN entrypoint/build.sh

EXPOSE 22
ENTRYPOINT ["entrypoint/start.sh"]
