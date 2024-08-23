#!/bin/bash

banner() {
  echo
  echo "============================================="
  echo $1
  echo "============================================="
}

# Work in build dir
mkdir -p _build
cd _build

# Initialization
dirname=WODA-current
sourcedir="WODA.test:/var/dev/EAMD.ucp/Scenarios/de/1blu/v36421/vhosts/de/wo-da/test/EAM/2_systems/Docker/StructrServer.v2.1.4/Workspaces/structrAppWorkspace"
destdir=.
date=$(date +%Y-%m-%d-%H_%M)
tarfile=backup-structr-${date}_${dirname}.tar.gz
rsynclog=_rsync.log
rm -rf backup-structr-* $rsynclog
if [[ -n "${keyfile}" ]]; then
  echo "Use ${keyfile}"
  use_key="-i ${keyfile}"
fi

BACKUP_DIR="/var/backups/test.wo-da.de_structr"
BACKUP_DESTINATION="backup.sfsre.com:$BACKUP_DIR"

# Get data
banner "Get data from $sourcedir"
while true; do
  rsync -avzP --delete -e "ssh $use_key -o 'StrictHostKeyChecking no'" $sourcedir/$dirname $destdir | tee $rsynclog
  if [ -z "$(cat $rsynclog | grep $dirname)" ]; then
    break
  else
    echo "Repeat because changes applied"
    sleep 5
  fi
done

# Create tar
banner "Create $tarfile"
cd $destdir
tar -czf ${tarfile} ${dirname}
ls -lah

# Copy to backup server
banner "Copy to backup server"
rsync -avzP -e "ssh $use_key -o 'StrictHostKeyChecking no'" $tarfile $BACKUP_DESTINATION/
latest_tarfile=backup-structr-latest_${dirname}.tar.gz
ssh $use_key -o 'StrictHostKeyChecking no' backup.sfsre.com bash -s << EOF
cd $BACKUP_DIR
rm -rf $latest_tarfile
ln -s $tarfile $latest_tarfile
EOF

# Tag dev/neom
tag=tag/neom/backup-structr-${date}
cd /var/dev/EAMD.ucp
git checkout dev/neom
git pull
git tag $tag

# Push tag to bitbucket
if ! git remote | grep -q token; then
  git remote add token https://x-token-auth:$BBTOKEN@bitbucket.org/donges/eamd.ucp.git
fi
git push -v token $tag

# Cleanup
banner "Cleanup"
rm -rf $tarfile $rsynclog
