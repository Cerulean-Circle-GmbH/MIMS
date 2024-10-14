#!/bin/sh
. bin/config
LOGS_DIR="logs"

# Link from /var/lib/structr-volume/ (we are in /var/lib/structr)
for dir in db files layouts logs sessions snapshots; do
  echo "Checking $dir"
  if [ ! -L '$dir' ]; then
    echo "Linking /var/lib/structr-volume/$dir to $dir"
    ln -s /var/lib/structr-volume/$dir $dir
  fi
done

echo "============================="
echo "Show /var/lib/structr/:"
ls -la .
echo "-----------------------------"
echo "Show /var/lib/structr-volume/:"
ls -la /var/lib/structr-volume/
echo "============================="

if [ -e $PID_FILE ]; then

  $(ps aux | grep "org.structr.Server" | grep -v grep)

  result=$?

  if [ $result -eq 1 ]; then
    echo
    echo "        Found $PID_FILE, but server is not running."
    echo "        Removing $PID_FILE and proceeding with startup."
    echo

    rm $PID_FILE
  else
    echo
    echo "        ERROR: server already running."
    echo
    echo "        Please stop any running instances before starting a"
    echo "        new one. (Remove $PID_FILE if this message appears"
    echo "        even if no server is running.)"
    echo

    exit 0
  fi

fi

if [ ! -d $LOGS_DIR ]; then
  echo "        Creating logs directory..."
  mkdir $LOGS_DIR
  touch $LOG_FILE
fi

echo -n "        Starting structr server $DISPLAY_NAME: "

java $RUN_OPTS $JAVA_OPTS $MAIN_CLASS > $LOG_FILE 2>&1 &
echo $! > $PID_FILE

sleep 1

echo "OK"

tail -f $LOG_FILE
