# ONCE Jenkins

## Container create
```
devTool docker.build
```

## Container start
```
devTool docker.up
```

## Backup configration

Outside in host:
```
docker run --rm -v once_jenkins_home:/var/jenkins_home -v $(pwd):/backup ubuntu tar cvf /backup/backup.tar /var/jenkins_home
```

In sibling container with /var/dev:
```
docker run --rm -v once_jenkins_home:/var/jenkins_home -v once_once-development:/var/dev ubuntu tar cvf /var/dev/backup.tar /var/jenkins_home
```

## Recreate configuration in new container

In sibling container with /var/dev:
```
docker run --rm -v once_jenkins_home:/var/jenkins_home -v once_once-development:/var/dev ubuntu /bin/bash -c "tar xvf /var/dev/backup.tar -C / && chown -R 1000:1000 /var/jenkins_home && find /var/jenkins_home"
```

Check permission & installation
```
# jenkins user and group have the uid/gid of 1000
docker run --rm -v once_jenkins_home:/var/jenkins_home -v once_once-development:/var/dev ubuntu /bin/bash -c "groupadd -g 1000 jenkins && useradd jenkins -u 1000 -g 1000 -m -s /bin/bash && find /var/jenkins_home && ls -la /var/jenkins_home"
```
