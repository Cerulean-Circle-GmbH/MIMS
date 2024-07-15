# Once.2023

## Download and start container
This installation assume that VS Code, ssh and Docker is already installed on your system and in the search path of your shell.

* Create a directory of your choice and open a shell there
* Start the container by calling:
```
curl -O https://raw.githubusercontent.com/Cerulean-Circle-GmbH/once.sh/main/once.2023/docker-compose.yml
docker compose -f docker-compose.yml up
```

## Login to container

### ssh
* Now open another shell (e.g. in WSL on Windows or native on Mac) and call:
```
ssh root@localhost -p 8022
# password is: once
```
* You are logged in now

### Connect with VS Code
* Start VS Code
* Click bottom left “><“ (“Open a remote Window”)
* Type “Attach" and Click "Attach to Running Container...")
* Select '/once.sh_container'
* Now you are inside the container
* Open a shell with “Terminal”→”New Terminal”
* Open the folder '/var/dev/EAMD.ucp/'

## Run and test server
* Call:
```
once restart
```
* Test now with
   * http://localhost:8080
   * https://localhost:8443


## Shortcuts:

* [What is Once.2023](#what-is-Once.2023)
* [First steps](#first-steps)
* [You are on main branch](#dev-branch)
* [Ups...I am a user](#wrong-here?)

## What is Once.2023

ONCE is an acronym for: Obejct Communication Network Environment.

It's purpose is to plant a seed for a decentralised internet.

It main goals are to make the internet more
* homogenous
* simple
* compatible

and for the first time ever object oriented!

### Objects 
Objects can be added to the object oriented internet very simply. And the ultimate goal is that all objects will be able to communicate to each other, to interact and from the next version of the a decentral internet. This will deprecate the page or app approach of the internet 2.0 complety and replace it with a Web 4.0. 

### Internet and its versions
To learn more about the concepts visit our pages that help you understand...

## First steps

1. [get it on your environment](#get-it)
1. [check if your system is already Web 4.0 enabled](#check-it)

### get it 
on your environment
Open a terminal and type

```
git clone git@github.com:Cerulean-Circle-GmbH/Once.2023.git

### if you have the deploy key
git clone githubCC.once2023:Cerulean-Circle-GmbH/Once.2023.git


### with .ssh/config entry
Host githubCC.once2023
 User git
 Port 22
 HostName github.com
 IdentityFile ~/.ssh/ids/once2023.githubCC/id_rsa


```
no git?
maybe you are not a developer? 

as a user [go here](https://github.com/Cerulean-Circle-GmbH/once.sh#fast-install---use-it-anywhere)
### check it 
if your system is already Web 4.0 enabled.


```
cd Once.2023
./check-system.sh
```

## Main branch
This is the main release branch.

To switch to dev branch type
```
devTool commit
```

to release type
```
devTool release
```

# Wrong here?
Ups, I am a USER. [Where should I go?](https://tech4people.cloud)

I wanted to go to your pages
* [Your homepage](https://ceruleancircle.com)
* [Your IoT homepage](https://iot.ceruleancircle.com)
* [Your homepage preview](https://testing.ceruleancircle.com)

I wanted to go to your apps
* [WODA](https://prod.wo-da.de)
* [The WODA Repository](https://prod.wo-da.de/EAMD.ucp)
* [The Once Versions](https://prod.wo-da.de/EAMD.ucp/Components/tla/EAM/layer1/Thinglish/Once)
    * [2.3.2](https://prod.wo-da.de/EAMD.ucp/Components/tla/EAM/layer1/Thinglish/Once/2.3.2/src/html/Once.html)
    * [3.1.0](https://prod.wo-da.de/EAMD.ucp/Components/tla/EAM/layer1/Thinglish/Once/3.1.0/src/html/Once.html)
    * [4.3.0](https://prod.wo-da.de/EAMD.ucp/Components/tla/EAM/layer1/Thinglish/Once/4.3.0/src/html/Once.html)
    * [4.5.0](https://prod.wo-da.de/EAMD.ucp/Components/tla/EAM/layer1/Thinglish/Once/4.3.0/src/html/Once.html)
