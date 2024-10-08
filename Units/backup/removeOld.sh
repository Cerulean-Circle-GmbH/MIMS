#!/usr/bin/env bash

# backup dir
BACKUP_DIR=$1

# file prefix
FILE_PREFIX=$2

nr_files_to_keep=$3

if [ -z $FILE_PREFIX ]; then
  echo "usage: $0 <backup_dir> <file_prefix> <nr_files_to_keep>"
  exit 1
fi

# amount of files to always keep
KEEP_COUNT=${nr_files_to_keep:-30}

# enter backup dir or exit
cd "$BACKUP_DIR" || exit 1

# find all backup files, sort descending (newest first)
backup_files=$(find . -maxdepth 1 -type f -name "$FILE_PREFIX-*.tar.gz" | sort -r)

# count files
file_count=$(echo "$backup_files" | wc -l)

# keep newest files amount as specified
if [ "$file_count" -gt "$KEEP_COUNT" ]; then
  files_to_keep=$(echo "$backup_files" | head -n "$KEEP_COUNT")

  echo "Keep newest $KEEP_COUNT files:"
  echo "$files_to_keep" | while read -r file; do
    echo " ++ keep file:   $file"
  done

  # find files of previous month which are older than the specified amount
  remaining_files=$(echo "$backup_files" | tail -n +$((KEEP_COUNT + 1)))

  #echo "Work on previous month"

  # extract year and month of remaining files
  echo "$remaining_files" \
    | sed -E "s/.*$FILE_PREFIX-([0-9]{4})-([0-9]{2})-.*/\1-\2/" \
    | sort -u -r \
    | while read -r year_month; do
      echo "${year_month}:"
      # find latest file of every month
      latest_file=$(find . -maxdepth 1 -type f -name "$FILE_PREFIX-${year_month}-*.tar.gz" \
        | sort -r \
        | head -n 1)
      echo " Keep latest file of $year_month: $latest_file"

      # delete all other files of month
      find . -maxdepth 1 -type f -name "$FILE_PREFIX-${year_month}-*.tar.gz" \
        | sort -r \
        | grep -v "$latest_file" \
        | while read -r old_file; do
          # ignore file, if it is already in $files_to_keep
          if echo "$files_to_keep" | grep -q "$old_file"; then
            # ignore file
            echo " ** ignore file: $old_file"
          else
            echo " -- delete file: $old_file"
            # rm "$old_file"
          fi
        done
    done
else
  echo "There are less than $KEEP_COUNT files, so nothing to delete."
fi
