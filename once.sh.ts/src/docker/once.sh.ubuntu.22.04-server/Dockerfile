# Use an official Python runtime as a parent image
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND noninteractive
ENV WORKDIR /root/
WORKDIR $WORKDIR
RUN export PATH=.:$PATH

# Install various packages
RUN apt update && apt install wget rsync openssh-server -y
RUN apt update && apt install net-tools errno -y
RUN apt update && apt install docker.io docker-compose -y
RUN apt update && apt install plantuml -y
RUN apt update && apt install golang-go -y

# Fix nodejs problem on ubuntu
# (See https://github.com/nodesource/distributions/issues/1157#issuecomment-1131212089)
RUN dpkg --remove --force-remove-reinstreq libnode-dev
RUN dpkg --remove --force-remove-reinstreq libnode72:amd64
RUN dpkg --remove --force-remove-reinstreq libnode72:arm64

# build all things inside container
ADD entrypoint entrypoint
RUN entrypoint/build.sh

EXPOSE 22
ENTRYPOINT ["entrypoint/start.sh"]
