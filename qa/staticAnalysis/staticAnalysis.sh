#!/bin/bash

dir=$1

banner() {
    echo
    echo "============================================="
    echo $1
    echo "============================================="
}

# Analyse broken links
banner "Analyse broken links in $dir"
search_links() {
  for file in "$1"/*; do
    if [ -L "$file" ]; then # check if file is a symbolic link
      if [ ! -e "$file" ]; then # check if target of the link exists
        echo "[ERROR] Broken link found: $file"
      fi
    elif [ -d "$file" ]; then # check if file is a directory
      search_links "$file" # recursively search directory
    fi
  done
}
search_links "$dir"

# Analyse dependency to test.wo-da.de
banner "Analyse dependency to test.wo-da.de in $dir/Components"
grep -r "test.wo-da.de" "$dir/Components" | while read line; do echo "[ERROR] Wrong dependency found: $line"; done

dir=/home/shared/EAMD.ucp/Components/com/ceruleanCircle/EAM/1_infrastructure/Once.sh/dev/

# Analyse dependency to test.wo-da.de
banner "Analyse dependency to test.wo-da.de in $dir"
grep -r "test.wo-da.de" "$dir" | while read line; do echo "[ERROR] Wrong dependency found: $line"; done

# Analyse deprecated functions
banner "Analyse deprecated functions in $dir"
grep -rn "deprecated" "$dir" | while read line;
do
  token=$(echo $line | sed "s;.*deprecated;deprecated;" | sed "s;[ ()\"].*;;");
  echo "[ERROR] Deprecated found ($token): $line";
done | sort | sed "s;$dir;./;"
