# Use an official Python runtime as a parent image
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND noninteractive
ENV WORKDIR /root/
WORKDIR $WORKDIR
RUN export PATH=.:$PATH

# wget is necessary for build.sh
RUN apt update
RUN apt install wget -y

# Use better Docker caching for recurring build (saves up to 5min during rebuild when only build.sh changed)
RUN apt install git -y
RUN apt install curl libcurl4 -y
RUN apt install net-tools -y
RUN apt install openssh-server -y
RUN apt install errno -y
RUN apt install docker.io -y
RUN apt install docker-compose -y
RUN apt install liblmdb0 libmaxminddb0 libuv1 bind9-libs bind9-host bind9-dnsutils dnsutils inetutils-ping -y
RUN apt install nodejs -y

# build all things inside container
ADD entrypoint entrypoint
RUN entrypoint/build.sh

EXPOSE 22
ENTRYPOINT ["entrypoint/start.sh"]
#CMD ["/usr/bin/sudo", "/usr/sbin/sshd", "-D", "-o", "ListenAddress=0.0.0.0"]
