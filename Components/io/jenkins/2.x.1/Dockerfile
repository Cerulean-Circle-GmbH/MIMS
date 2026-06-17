FROM jenkins/jenkins:lts
USER root
RUN apt-get update && apt-get install -y docker.io docker-compose acl yq sudo openvpn
RUN usermod -aG docker jenkins

# Passwordless sudo für jenkins, aber nur für die zwei Befehle, die withOpenVPN braucht
RUN echo "jenkins ALL=(root) NOPASSWD: /usr/sbin/openvpn, /bin/kill" \
        > /etc/sudoers.d/jenkins-openvpn \
    && chmod 0440 /etc/sudoers.d/jenkins-openvpn \
    && visudo -cf /etc/sudoers.d/jenkins-openvpn

USER jenkins
