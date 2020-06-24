#!/bin/sh

# 10 min interval
INTERVAL=600
STOP=stop

download_repository() {
    echo "swift download $1"
    swift download $1
}

upload_repository() {
    swift upload $1 repository/ sync/
}

watch_upload() {
    trap 'kill -TERM $PIDSLEEP' SIGTERM

    while ! [ -f $STOP ]
    do
	sleep $INTERVAL &
	PIDSLEEP=$!
	wait $PIDSLEEP
	date
	upload_repository $1
    done
}

before_exit() {
    kill -TERM $2
    wait $2
    touch $STOP
    kill -TERM $3
    wait $3
    rm $STOP
}

trap 'before_exit $1 $PID_INSTANCE $PID_WATCH; exit 143' TERM

download_repository $1
learn-ocaml --sync=sync --repo=repository &
PID_INSTANCE=$!

watch_upload $1 &
PID_WATCH=$!

wait $PID_INSTANCE
