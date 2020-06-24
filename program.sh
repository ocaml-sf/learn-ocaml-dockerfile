#!/bin/sh
REPOSITORY=repository
SYNC=sync

download_repository() {
	echo "swift download $1"
	swift download $1
	unzip $REPOSITORY.zip $SYNC.zip
	rm $REPOSITORY.zip $SYNC.zip
}

upload_repository() {
	zip $REPOSITORY.zip -r $REPOSITORY
	zip $SYNC.zip -r $SYNC
	echo "swift upload $1"
	swift upload --changed $1 $REPOSITORY.zip $SYNC.zip
}

trap 'kill -TERM $PID; wait $PID; upload_repository $1; exit 143' TERM

download_repository $1
dumb-init learn-ocaml --sync=sync --repo=repository &
PID=$!
wait $PID
