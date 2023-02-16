BRANCH=`git symbolic-ref --short -q HEAD`

echo "Build all images in branch: $BRANCH"

# build image once.jenkins
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
           --entrypoint "" once.sh-builder /bin/bash -c \
           "source ~/config/user.env &&
           git clone 2cuGitHub:Cerulean-Circle-GmbH/Once.2023.git &&
           cd Once.2023 &&
           git checkout $BRANCH &&
           cd once.sh.ts/src/docker/jenkins &&
           ./devTool docker.build"

# build image once.sh-builder
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
           --entrypoint "" once.sh-builder /bin/bash -c \
           "source ~/config/user.env &&
           git clone 2cuGitHub:Cerulean-Circle-GmbH/Once.2023.git &&
           cd Once.2023 &&
           git checkout $BRANCH &&
           cd once.sh.ts/src/docker/once.sh.ubuntu.22.04-builder &&
           ./devTool docker.build"

# build image once.sh-server
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
           --entrypoint "" once.sh-builder /bin/bash -c \
           "source ~/config/user.env &&
           git clone 2cuGitHub:Cerulean-Circle-GmbH/Once.2023.git &&
           cd Once.2023 &&
           git checkout $BRANCH &&
           cd once.sh.ts/src/docker/once.sh.ubuntu.22.04-server &&
           ./devTool docker.build"

# build image once.sh-server multi-branch
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
           --entrypoint "" once.sh-builder /bin/bash -c \
           "source ~/config/user.env &&
           git clone 2cuGitHub:Cerulean-Circle-GmbH/Once.2023.git &&
           cd Once.2023 &&
           git checkout $BRANCH &&
           cd once.sh.ts/src/docker/once.sh.ubuntu.22.04-server &&
           ./devTool docker.buildx.use echo $DOCKER_PASSWORD | docker login -u donges --password-stdin &&
            devTool docker.buildx.push"

# Example to use image interactively
#docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock --entrypoint "" once.sh-builder /bin/bash