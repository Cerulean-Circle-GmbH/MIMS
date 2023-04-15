#!/bin/bash

pushd ~/entrypoint > /dev/null

# List files before oosh install
./showFiles.sh > ./01_ls-before-oosh.txt

# Download and install oosh
./install-oosh.sh

# List files after oosh install
./showFiles.sh | grep -v /root/.ssh > ./02_ls-after-oosh-install.txt

# Install ONCE
./install-once.sh

# List files after ONCE install
./showFiles.sh | grep -v /root/.ssh | grep -v /root/.npm | grep -v /var/dev/EAMD.ucp > ./03_ls-after-ONCE-install.txt

# ONCE uninstall
source ~/config/user.env
once clean

# List files after ONCE deinstall
./showFiles.sh | grep -v /root/.ssh | grep -v /root/.npm | grep -v /var/dev/EAMD.ucp > ./04_ls-after-ONCE-deinstall.txt

# Deinstall and reinstall oosh
/home/shared/EAMD.ucp/Components/com/ceruleanCircle/EAM/1_infrastructure/Once.sh/dev/init/deinstall.oosh

# List files after oosh deinstall
./showFiles.sh | grep -v /root/.ssh | grep -v /root/.npm | grep -v /var/dev/EAMD.ucp > ./05_ls-after-oosh-deinstall.txt

popd > /dev/null
