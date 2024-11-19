# MIMS

Minimal Infrastructre Management Service

## Assumptions

You have Windows, Mac or Linux.
You already installed:

- Git
- Docker
- Bash (e.g. Git-Bash on Windows)
- SSH (e.g. Git-Bash on Windows)
- Visual Studio Code -> recommended extensions: WSL, Remote Development (=Dev Containers+Remote SSH+Remote Explorer), Bash IDE, GitLens

And the commands are in the `PATH`.

- You know where your ssh keys are (ideally they are in your {homedir}/.ssh)
- You have a working Github.com account with your ssh public key added
- You have a working bitbucket.org account with your ssh public key added

## Install

```
cd ~/workspace/dev (suggested parent dir, so create it if not existing)
git clone git@github.com:Cerulean-Circle-GmbH/MIMS.git
cd MIMS
./scenario.deploy localhost/dev init,up -v
```

The first starting might take a while to install everything. You also need to answer some questions (in **bold** are the recommended answers, the other questions uses the default values shown inside the brackets [] by just pressing ENTER):

- Do you want to continue with this scenario and create a new one? (yes/no) [no]: **yes**
- Choose available component dir []: **com/ceruleanCircle/EAM/2_systems/WODA**
- This is the cache directory for downloaded files, like structr.zip or WODA-current.tar.gz [~/.cache/MIMS-Scenarios]:
- What is the server, the scenario will be deployed? [test.wo-da.de]: **localhost**
- Where to find the servers letsencrypt base dir? [/var/dev/EAMD.ucp/Scenarios/de/1blu/v36421/vhosts/de/wo-da/test/EAM/1_infrastructure/Docker/CertBot.v1.7.0/config]: **none**
- Where to find the servers certificate? [/var/dev/EAMD.ucp/Scenarios/de/1blu/v36421/vhosts/de/wo-da/test/EAM/1_infrastructure/Docker/CertBot.v1.7.0/config/conf/live/test.wo-da.de]: **none**
- What is the path of the data volume (e.g. './data' or 'data-volume'; if it contains a '/', it is considered as a path, otherwise as a docker volume name)? [./data]: **~/workspace/dev**
- Where to find the restore data (none - if not applicable)? [none]:
- Is the data volume external (true or false; if not external, it will be deleted on down)? [true]:
- What is the docker container name? [${SCENARIO_NAME}_once.sh_container]:
- Which ONCE docker image should be used? [donges/once:latest]:
- Which ONCE branch should be restored (maybe tag dependent)? [none]: **dev/WODA**
- Which path should be used as outer config? [~]:
- What is the ONCE http port? [8080]:
- What is the ONCE https port? [8443]:
- What is the ONCE container SSH port? [8022]:
- What is the ONCE reverse proxy http port? [5002]:
- What is the ONCE reverse proxy https port? [5005]:

## Commands

Call `./scenario.deploy -h` for help.

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

_Remark:_
Even with "StrictHostKeyChecking no" the fingerprint of the last running container after recreation of the container might need to be removed from your `~/.ssh/known_hosts` before login. You need this if you see:

```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
```

You are logged in now.

## Connect with VS Code

- Start VS Code
- Click bottom left “><“ (“Open a remote Window”)
- Type “Attach" and Click "Attach to Running Container..." (Install the Extension “Dev Containers” before. See Install on Windows 10 | Recommended extensions )
- Select /once.sh_container
- Now you are inside the container
- Open a shell with “Terminal”→”New Terminal”
- Open the folder /var/dev/EAMD.ucp/

## Run and test server

Call:

```
once restart

#or
once stop
once start
```

Test now with

- http://localhost:8080/EAMD.ucp
- https://localhost:8443/EAMD.ucp

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

---

# What will happen during startup?

Initially depending on the system the correct `docker-compose.yml` file is created. You can later adapt it. You can also just delete it. It will be recreated at the next start.

## Policy for your user configuration (git and ssh)

The git (`.gitconfig`) and ssh configuration (`.ssh/id_rsa*`) inside the container needs to be imported from your host. This will be done in the following order

- If there is configuration in MIMS/\_myhome I take
- If there is configuration in $HOME resp. %USERPROFILE% I take
- If not I create it in MIMS/\_myhome

If you didn’t have all the files (.ssh…, .gitconfig…) before the first start (=creation of the container) you can delete the container (or `down.sh`) and recreate it with the same command.

Attention: All changes in the file system are gone, except in /var/dev because it is in your volume or your host.

# Policy for the location of the EAMD.ucp code

The source code for EAMD.ucp is stored either in a docker volume (necessary on Windows!) or on your local system. If the repository doesn't exist at startup, it will be downloaded.

On Mac and Linux you can also choose a local directory. It will search at the following positions:

- `~/workspace/dev`
- `/var/dev`
