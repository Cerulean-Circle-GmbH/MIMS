# Once.2023

Purpose of this project when its done:
do a 
```
   docker pull once.sh (or better a docker compose file)
```
and have a complete installation.

Connect to the running container via docker or VS Code or call:
```
   ssh-keygen -R [localhost]:8022 # Call this only one time after creation of the container
   ssh root@localhost -p 8022 # password is "once"
```

To start a Once server call this inside the container:
```
   once restart
```
Then go to http://localhost:8080


## shortcuts:

* [What is Once.2023](#what-is-Once.2023)
* [First steps](#first-steps)
* [You are on dev branch](#dev-branch)
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

## Dev branch
This is the main development branch.

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
