#!/bin/bash

dir_and_prefix=$1
no_files_to_keep=$2

if [ -z $no_files_to_keep ]; then
  echo "usage: $0 <dir_and_prefix> <no_files_to_keep>"
  exit 1
fi

declare -i i=$no_files_to_keep
for f in $(find ${dir_and_prefix}* | sort -r); do
  if [ $i != 0 ]; then
    i=$((i - 1))
    echo "keep $f"
  else
    echo "remove $f"
    rm $f
  fi
done
