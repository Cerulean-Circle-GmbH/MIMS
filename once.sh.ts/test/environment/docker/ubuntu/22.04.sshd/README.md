# docker with sshd suppoer

## use sh scripts

```

c2 devTool docker[press TAB]


c2 devTool docker.status
c2 devTool docker.build
c2 devTool docker.run

## deprecated
#buidDockerfile
#runDockerfile
```

## start ssh inside the container
```
service --status-all
```

```
service ssh restart

service ssh --full-restart
```

## login from outside with

```
ssh -p 8022 test@localhost
```

pw test



## manual work with docker
```
docker build -t naked_ubuntu .
```

```
docker run -it naked_ubuntu bash
```
