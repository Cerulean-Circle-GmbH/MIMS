# docker with sshd suppoer

## use sh scripts

```
buidDockerfile
runDockerfile
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
