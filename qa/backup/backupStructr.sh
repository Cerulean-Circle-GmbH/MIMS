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
tarfile=${date}_${dirname}.tar.gz
rsynclog=_rsync.log
rm -rf 20*.tar.gz $rsynclog
if [[ -n "${keyfile}" ]]; then
    echo "Use ${keyfile}"
    use_key="-i ${keyfile}"
fi

# Get data
banner "Get data from $sourcedir"
while true; do
    rsync -avzP --delete -e "ssh $use_key -o 'StrictHostKeyChecking no'" $sourcedir/$dirname $destdir | tee $rsynclog
    if [ -z "$(cat $rsynclog | grep $dirname)" ]; then
        break;
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
rsync -avzP -e "ssh $use_key -o 'StrictHostKeyChecking no'" $tarfile backup.sfsre.com:/var/backups/structr/