FROM jenkins/jenkins:lts
USER root
# rsync: scenario.deploy 'init' überträgt das Szenario per rsync auf den Host.
# curl: zum Laden von yq (unten).
RUN apt-get update && apt-get install -y docker.io docker-compose acl sudo openvpn rsync curl \
    && rm -rf /var/lib/apt/lists/*

# yq von mikefarah (v4): scenario.deploy braucht 'yq eval-all'. Das Debian-Paket 'yq' ist das
# Python-yq (kislyuk) und kennt den Befehl nicht — deshalb nicht aus apt, sondern wie in
# Units/docker-images/*/Dockerfile. Architektur folgt dem Build-Host (amd64/arm64).
ARG YQ_VERSION=v4.44.5
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}.tar.gz" \
       | tar xz -C /tmp \
    && mv "/tmp/yq_linux_${ARCH}" /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && yq --version | grep -q mikefarah
RUN usermod -aG docker jenkins

# Passwordless sudo für jenkins, aber nur für die zwei Befehle, die withOpenVPN braucht
RUN echo "jenkins ALL=(root) NOPASSWD: /usr/sbin/openvpn, /bin/kill" \
        > /etc/sudoers.d/jenkins-openvpn \
    && chmod 0440 /etc/sudoers.d/jenkins-openvpn \
    && visudo -cf /etc/sudoers.d/jenkins-openvpn

USER jenkins
