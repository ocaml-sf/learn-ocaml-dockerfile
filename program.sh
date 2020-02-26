#!/bin/sh

# 10 min interval
INTERVAL=10
STOP=stop

download_repository() {
    echo "swift download $1"
    swift download $1
}

upload_repository() {
    swift upload $1 repository/ sync/
} 

watch_upload() {
    while ! [ -f $STOP ]
    do
	sleep $INTERVAL
	date
	upload_repository $1
    done
}

before_exit() {
    kill -TERM $2
    wait $2
    touch $STOP
    wait $3
    rm $STOP
    upload_repository $1
}

trap 'before_exit $1 $PID_INSTANCE $PID_WATCH; exit 143' TERM

download_repository $1
dumb-init learn-ocaml --sync=sync --repo=repository &
PID_INSTANCE=$!

watch_upload $1 &
PID_WATCH=$!

wait $PID_INSTANCE
