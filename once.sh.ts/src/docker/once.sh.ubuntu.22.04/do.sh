#!/bin/sh
set -e
devTool docker.build #.progressplain
echo "============== BUILD SUCCESS =============="
devTool docker.run