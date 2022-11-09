#!/bin/sh

echo "Starting custom build script: $0"

apt update && apt install  net-tools wget openssh-server sudo -y
useradd -rm -d /home/ubuntu -s /bin/bash -g root -G sudo -u 1000 test 
echo 'test:test' | chpasswd
echo 'test:test' | sudo chpasswd
service ssh start

# generate server keys
ssh-keygen -A
#RUN ssh-keygen -t dsa -N "my passphrase" -C "test key" -f mykey
ssh-keygen -t rsa -q -f "$HOME/.ssh/id_rsa" -N ""

# allow root to login
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
