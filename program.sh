#!/bin/sh

download_repository() {
	echo "swift download $1"
	swift download $1
}

upload_repository() {
	swift upload --changed $1 repository/ sync/
} 

trap 'kill -TERM $PID; wait $PID; upload_repository $1; exit 143' TERM

download_repository $1
dumb-init learn-ocaml --sync=sync --repo=repository &
PID=$!
wait $PID
