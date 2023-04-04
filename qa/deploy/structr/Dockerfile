FROM openjdk:8-jdk-alpine

#ARG STRUCTR_VERSION
ARG JAVA_OPT_XMS=4
ARG JAVA_OPT_XMX=4

ARG UID=${SCENARIO_STRUCTR_UID}
ARG GID=${SCENARIO_STRUCTR_GID}

USER ${UID}:${GID}
ENV JAVA_OPT_XMS=$JAVA_OPT_XMS
ENV JAVA_OPT_XMX=$JAVA_OPT_XMX

ENV WORK_DIR /var/lib/structr
ENV PATH="${PATH}:${WORK_DIR}/scripts"

ENV TERM="xterm"
ENV defaultServer="${SCENARIO_STRUCTR_SERVER}"

RUN apk add unzip git tree ncurses openssh-client bash curl wget
RUN mkdir ${WORK_DIR}
WORKDIR ${WORK_DIR}
ADD _data/structr.zip /
RUN unzip -q /structr.zip -d /var/lib && rm /structr.zip
ADD structr.conf ${WORK_DIR}/
ADD _data/keystore.pkcs12 ${WORK_DIR}/
RUN mkdir /usr/lib/structr
ADD _data/keystore.pkcs12 /usr/lib/structr/
ADD start-structr.sh ${WORK_DIR}/bin

#ENTRYPOINT [ "/bin/sh", "/var/lib/structr/bin/docker.sh" ]
ENTRYPOINT [ "bin/start-structr.sh" ]
#CMD [ $JAVA_OPT_XMS, $JAVA_OPT_XMX ]
