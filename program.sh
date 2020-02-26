#!/bin/sh

# 10 min interval
INTERVAL=600

download_repository() {
	echo "swift download $1"
	swift download $1
}

upload_repository() {
	swift upload $1 repository/ sync/
} 

CONTINUE=true
watch_upload() {
	while $CONTINUE
	do
		upload_repository $1
		sleep $INTERVAL
	done
}

trap 'kill -TERM $PID; wait $PID; upload_repository $1; exit 143' TERM

download_repository $1
dumb-init learn-ocaml --sync=sync --repo=repository &
PID_INSTANCE=$!

watch_upload &
PID_WATCH=$!

wait $PID_INSTANCE
CONTINUE=false
wait $PID_WATCH
