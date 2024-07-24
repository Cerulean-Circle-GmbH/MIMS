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
ADD ../../_cache/structr.zip /
RUN unzip -q /structr.zip -d /var/lib && rm /structr.zip
# Necessary hotfix for schema saving (JavaScript ESX changes)
RUN sed -i 's;+/,;+/g,;g' /var/lib/structr/structr/js/schema.js
ADD structr.conf ${WORK_DIR}/
ADD _data/keystore.pkcs12 ${WORK_DIR}/
RUN mkdir /usr/lib/structr
ADD _data/keystore.pkcs12 /usr/lib/structr/
ADD start-structr.sh ${WORK_DIR}/bin

# Prepare links to the scripts and /EAMD.ucp to link into mounted volume
RUN rm -rf /var/lib/structr/scripts && mkdir -p /var/lib/structr
RUN mkdir -p /var/dev/EAMD.ucp/Components/tla/EAMD/UcpComponentSupport/1.0.0/src/sh
RUN ln -s /var/dev/EAMD.ucp /EAMD.ucp
RUN ln -s /var/dev/EAMD.ucp/Components/tla/EAMD/UcpComponentSupport/1.0.0/src/sh /var/lib/structr/scripts
RUN rm -rf /var/dev/EAMD.ucp

#ENTRYPOINT [ "/bin/sh", "/var/lib/structr/bin/docker.sh" ]
ENTRYPOINT [ "bin/start-structr.sh" ]
#CMD [ $JAVA_OPT_XMS, $JAVA_OPT_XMX ]
