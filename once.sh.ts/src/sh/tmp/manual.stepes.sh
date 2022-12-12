cp -r config.initial/stateMachines/ config

apt install software-properties-common apt-transport-https
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
apt install code
oo cmd snapd
snap install --classic code
oo cmd npm
docker
oo cmd docker.io