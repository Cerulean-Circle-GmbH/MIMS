#!/bin/bash
set -e

mkdir -p ~/startmsg
NOW=`date`
echo "This container was build: $NOW" > ~/startmsg/build.txt

echo "Starting custom build script: $PWD $0"

# Install https://github.com/remotemobprogramming/mob (Might need a go install
# github.com/remotemobprogramming/mob/v3@latest and recompile on arm64 ubuntu)
curl -sL install.mob.sh | sh

# List files before oosh install
~/entrypoint/showFiles.sh > ~/startmsg/01_ls-before-oosh.txt

# Download and install oosh
~/entrypoint/install-oosh.sh

# List files after oosh install
~/entrypoint/showFiles.sh > ~/startmsg/02_ls-after-oosh.txt

# Setup ssh and root login
echo 'root:once' | chpasswd
mkdir /var/run/sshd
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
