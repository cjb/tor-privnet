#!/bin/bash

# Control script to start, stop, reload, restart nodes or list their status
# in the private network.

source common.sh

print_usage() {
echo "Usage: {start|stop|restart|reload|status} \
[(auth|relay|client)n] ..." >&2
exit 1
}

if [ "$#" == "0" ]; then
	print_usage
fi

action=$1

shift

tors=

# No further arguments, act on all instances
if [ "$#" == "0" ]; then
for instance in $(find work/* -type d -maxdepth 1 -mindepth 1); do
	inst=`basename -a $instance`
	tors="$tors $inst"
done
fi

while (( "$#" )); do

	#Make sure we actually have a Tor instance for this
	if [ ! -d $WD/*/$1 ]; then
		echo "Can't find Tor instance $1. Ignoring." >&2
	else
	tors="$tors $1"
	fi

	shift

done

# Return 1 if this tor is running, 0 if not.
checkpid() {

if [ -e $WD/$1.pid ]; then
	pid=$(cat $WD/$1.pid)
	if ( kill -0 $pid );then
		PID=$pid
		return 1
	fi
fi
return 0
}

start() {

for inst in $tors; do
	checkpid "$inst"
	if [ "$?" != "0" ]; then
		echo "Tor process $inst is already running. Not starting." >&2
	else
		cd $WD
		echo "Starting Tor process $inst." >&2
		find . -type d -name "$inst" -exec bash -c "$TOR --quiet -f $WD/{}/torrc &" \;
	fi
done
}

stop() {
for inst in $tors; do
	PID=0
	checkpid "$inst"
	if [ "$?" == "0" ]; then
		echo "Tor process $inst is not running. Not stopping." >&2
	else
		echo "Stopping Tor process $inst." >&2
		kill -INT $PID
	fi
done
}

reload() {
for inst in $tors; do
	PID=0
	checkpid "$inst"
	if [ "$?" == "0" ]; then
		echo "Tor process $inst is not running. Not reloading." >&2
	else
		echo "Reloading Tor process $inst." >&2
		kill -HUP $PID
	fi
done
}

status() {
for inst in $tors; do
	PID=0
	checkpid "$inst"
	if [ "$?" == "0" ]; then
		echo "Tor process $inst is not running." >&2
	else
		echo "Tor process $inst is running with PID $PID" >&2
	fi
done
}

case "$action" in
  start)
	start
  ;;
  stop)
	stop
  ;;
  restart)
	stop
	start
  ;;
  reload)
	reload
  ;;
  status)
	status
  ;;
esac