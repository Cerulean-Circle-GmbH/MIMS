#!/bin/bash

dirname=WODA-current
sourcedir="WODA.test:/var/dev/EAMD.ucp/Scenarios/de/1blu/v36421/vhosts/de/wo-da/test/EAM/2_systems/Docker/StructrServer.v2.1.4/Workspaces/structrAppWorkspace"
destdir=.
date=$(date +%Y-%m-%d-%H_%M)
tarfile=${date}_${dirname}.tar.gz

rsync -avzP --delete $sourcedir/$dirname $destdir
cd $destdir
tar -czf ${tarfile} ${dirname}
ls
