# Use an official Python runtime as a parent image
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND noninteractive
ENV WORKDIR /root/
WORKDIR $WORKDIR
RUN export PATH=.:$PATH

# wget is necessary for build.sh
RUN apt update
RUN apt install wget -y
RUN apt install rsync -y
RUN apt install nodejs npm -y

# build all things inside container
ADD entrypoint entrypoint
RUN entrypoint/build.sh

EXPOSE 22
ENTRYPOINT ["entrypoint/start.sh"]
