# How to release Once.2023 

## make a change

2cuGitHub/Once.2023/once.sh.ts/src/docker/once.sh.ubuntu.22.04-server

- change DOCKER_IMAGE_VERSION=0.16x in 2cuGitHub/Once.2023/once.sh.ts/src/docker/once.sh.ubuntu.22.04-server/.env
- git commit and push
  - triggers https://test.wo-da.de/jenkins/job/Once.2023%20CI/
  - wait for successfull build of 0.16x-dev

## test with WODA.2023
-  2cuGitHub/WODA.2023    
  - woda up test16dev


        -> Use command            : up
        On branch main
        Your branch is up to date with 'origin/main'.

        nothing to commit, working tree clean
        Now running containers    : neom-once.sh_container
        Use config                : test16dev
        Docker image              : [donges/once:latest]: donges/once:0.16x-dev              
        Relative paths need to    : /Users/Shared/Workspaces/2cuGitHub/WODA.2023/_config.test16dev
        Type 'volume' if you want to use a docker volume
        EAMD.ucp source path      : [../_var_dev]: volume
        Volume name               : [once-development]: once-16-dev
        Possible config sources   : ../_myhome /Users/donges
        Import Git/SSH config from: [/Users/donges]: 
        HTTP port                 : [8080]: 6080
        HTTPS port                : [8443]: 6443
        SSH   port                : [8022]: 6022
        Reverse Proxy HTTP port   : [5002]: 6002
        Reverse Proxy HTTPS port  : [5005]: 6005
        You are about to (re)create and start the container (test16dev). Are you sure (yes/no)? [no]: yes
        [+] Pulling 12/12
  - if up correctly...

## release on git
- merge dev branch into main branch
- git push  
  - manually trigger https://test.wo-da.de/jenkins/job/Once.2023/
  - Build with Parameters
    - GIT_BRANCH: main
    - RELEASE_CMD: release
  - Build button
  - results in new image:    donges/once:latest = donges/once:0.16x on dockerHub