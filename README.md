# ONCE.2023

## Assumptions
You have Windows, Mac or Linux.
You already installed:
* Git
* Docker
* Bash (e.g. Git-Bash on Windows)
* SSH (e.g. Git-Bash on Windows)
* Visual Studio Code -> recommended extensions: WSL, Remote Development (=Dev Containers+Remote SSH+Remote Explorer), Bash IDE, GitLens

And the commands are in the ```PATH```.

* You know where your ssh keys are (ideally they are in your {homedir}/.ssh)
* You have a working Github.com account with your ssh public key added
* You have a working bitbucket.org account with your ssh public key added

## Install
```
git clone git@github.com:Cerulean-Circle-GmbH/Once.2023.git
cd Once.2023
./scenario.deploy localhost/dev init,up -v
```

The first starting might take a while to install everything. Yoiu also need to define some settings:

* component dir must be: ```com/ceruleanCircle/EAM/2_systems/WODA-with-Structr```
* docker image and branch can stay default (just press enter)
* outer config copies your .ssh and .gitconfig into your container. Should be your home: ```~```
* structr backup file for your structur container can stay default
* server must be: ```localhost```
* certificate dir can stay default
* volume can stay ```none``` or a volume name of a volume you already have
* source path can stay ```none``` or a path you locally use (not applicable on Windows and volume is in that case ignored)
* all ports can stay default

## Commands

Call ```./scenario.deploy -h``` for help.

## Login to the container

### With Docker directly

```
docker exec -it dev_once.sh_container /bin/bash
```

### With ssh
Now open another shell (e.g. in WSL on Windows or native on Mac or Linux) and call:

```
ssh -o "StrictHostKeyChecking no" root@localhost -p 8022
# password is: once
```

*Remark:*
Even with "StrictHostKeyChecking no" the fingerprint of the last running container after recreation of the container might need to be removed from your ```~/.ssh/known_hosts``` before login. You need this if you see:
```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
```

You are logged in now.

## Connect with VS Code
* Start VS Code
* Click bottom left “><“ (“Open a remote Window”)
* Type “Attach" and Click "Attach to Running Container..." (Install the Extension “Dev Containers” before. See Install on Windows 10 | Recommended extensions )
* Select /once.sh_container
* Now you are inside the container
* Open a shell with “Terminal”→”New Terminal”
* Open the folder /var/dev/EAMD.ucp/

## Run and test server
Call:

```
once restart
```
Test now with

* http://localhost:8080
* https://localhost:8443

## Install SSHFS for Browser Debugging on Windows with a volume

Install SSHFS to mount the filesystem of the container locally where your browser hase access.

```
winget install WinFsp.WinFsp
winget install SSHFS-Win.SSHFS-Win
```

Start the container and test ssh access

```
ssh -o "StrictHostKeyChecking no" root@localhost -p 8022
# password is: once
```
In an explorer goto to:

```
\\sshfs.r\root@localhost!8022\var\dev
```
And finally map it to U:
```
net use U: \\sshfs.r\root@localhost!8022\var\dev
```

****
# What will happen during startup?
Initially depending on the system the correct ```docker-compose.yml``` file is created. You can later adapt it. You can also just delete it. It will be recreated at the next start.

## Policy for your user configuration (git and ssh)
The git (```.gitconfig```) and ssh configuration (```.ssh/id_rsa*```) inside the container needs to be imported from your host. This will be done in the following order
* If there is configuration in WODA.2023/_myhome I take
* If there is configuration in $HOME resp. %USERPROFILE% I take
* If not I create it in WODA.2023/_myhome

If you didn’t have all the files (.ssh…, .gitconfig…) before the first start (=creation of the container) you can delete the container (or ```down.sh```) and recreate it with the same command.

Attention: All changes in the file system are gone, except in /var/dev because it is in your volume or your host.

# Policy for the location of the EAMD.ucp code
The source code for EAMD.ucp is stored either in a docker volume (necessary on Windows!) or on your local system. If the repository doesn't exist at startup, it will be downloaded.

On Mac and Linux you can also choose a local directory. It will search at the following positions:
* ```WODA.2023/_var_dev```
* ```/var/dev```
