#!/bin/bash

showFilesWithFilter() {
  ~/entrypoint/showFiles.sh | grep -v /root/.ssh | grep -v /root/.npm | grep -v /var/dev/EAMD.ucp
}

pushd ~/entrypoint > /dev/null

# List files before oosh install
showFilesWithFilter > ./01_ls-before-oosh.txt

# Download and install oosh
echo "testDeinstall.sh: Download and install oosh"
./install-oosh.sh

# List files after oosh install
showFilesWithFilter > ./02_ls-after-oosh-install.txt

# Install ONCE
echo "testDeinstall.sh: Install ONCE"
./install-once.sh

# List files after ONCE install
pushd /var/dev/EAMD.ucp > /dev/null
git status > ~/entrypoint/02_git-status-after-ONCE-install.txt
git ls-files --others --ignored --exclude-standard > ~/entrypoint/02_git-ls-files-after-ONCE-install.txt
popd > /dev/null
showFilesWithFilter > ./03_ls-after-ONCE-install.txt

# ONCE uninstall
echo "testDeinstall.sh: ONCE uninstall"
source ~/config/user.env
once clean
# This is missing already in the "once clean" command
echo "testDeinstall.sh: ONCE uninstall: remove other files"
rm -rf /var/dev/EAMD.ucp/Scenarios/buildkitsandbox
rm -rf /var/dev/EAMD.ucp/Components/tla/EAM/layer1/Thinglish/Once/*/node_modules
rm -rf /var/dev/EAMD.ucp/Components/tla/EAM/layer1/Thinglish/Once/*/package-lock.json
rm -rf /root/.local/share/mkcert/rootCA*
rmdir -p /root/.local/share/mkcert || true

# List files after ONCE deinstall
pushd /var/dev/EAMD.ucp > /dev/null
git status > ~/entrypoint/04_git-status-after-ONCE-deinstall.txt
git ls-files --others --ignored --exclude-standard > ~/entrypoint/04_git-ls-files-after-ONCE-deinstall.txt
popd > /dev/null
showFilesWithFilter > ./04_ls-after-ONCE-deinstall.txt

# Deinstall oosh
echo "testDeinstall.sh: Deinstall oosh"
/home/shared/EAMD.ucp/Components/com/ceruleanCircle/EAM/1_infrastructure/Once.sh/dev/init/deinstall.oosh

# List files after oosh deinstall
showFilesWithFilter > ./05_ls-after-oosh-deinstall.txt

popd > /dev/null
