#!/bin/sh
BACKUP=backup
REPOSITORY=repository
SYNC=sync

error() {
    echo "$1 failed" >&2
}

# 10 min interval
INTERVAL=600
STOP=stop

download_repository() {
    echo "swift download $1"
    swift download "$1"
    unzip -q $REPOSITORY.zip
    echo "unzipping $REPOSITORY.zip returns $?"
    rm -f $REPOSITORY.zip
    if [ -f $SYNC.zip ]
    then
        unzip -q $SYNC.zip
        echo "unzipping $SYNC.zip returns $?"
        rm -f $SYNC.zip
    fi
}

optimize_sync() {
    echo "optimizing using git gc"
    cd "$SYNC" || error "optimizing_sync: cd $SYNC" || return
    DIRS=$(find . -mindepth 4 -maxdepth 4 -type d -not -path "\./\.git*")
    for i in $DIRS
    do
        echo "$i"
        cd "$i" || error "optimizing_sync: cd $i" || continue
        git gc
        cd - || error "optimizing_sync: cd - (assert false)" || continue
    done
    git gc
    cd ..
    echo "optimizing done"
}

clone_sync() {
    rm -rf ${BACKUP:?}/$SYNC
    echo "cloning sync to avoid concurrency when writing"
    find $SYNC -name .git | while read -r repository; do
        git clone "$repository" $BACKUP/"$repository"
    done
    # copy directories which are not repositories yet
    echo "cp -rn $SYNC $BACKUP/$SYNC"
    cp -rn $SYNC $BACKUP
}

upload_repository() {
    # repository archiving
    zip -q $BACKUP/$REPOSITORY.zip -r $REPOSITORY
    echo "zipping $REPOSITORY returns $?"
    # sync archiving
    optimize_sync
    clone_sync
    cd $BACKUP && zip -q $SYNC.zip -r $SYNC && cd ..
    echo "cd && zipping $SYNC returns $?"
    ls -l $BACKUP
    echo "swift upload $1 --object-name $REPOSITORY.zip $BACKUP/$REPOSITORY.zip"
    swift upload --changed "$1" --object-name $REPOSITORY.zip $BACKUP/$REPOSITORY.zip
    echo "swift upload $1 --object-name $SYNC.zip $BACKUP/$SYNC.zip"
    swift upload --changed "$1" --object-name $SYNC.zip $BACKUP/$SYNC.zip
}

watch_upload() {
    trap 'kill -TERM $PIDSLEEP' TERM

    while ! [ -f $STOP ]
    do
	sleep $INTERVAL &
	PIDSLEEP=$!
	wait $PIDSLEEP
	date
	upload_repository "$1"
    done
}

before_exit() {
    kill -TERM "$2"
    wait "$2"
    touch $STOP
    kill -TERM "$3"
    wait "$3"
    rm $STOP
}

trap 'before_exit $1 $PID_INSTANCE $PID_WATCH; exit 143' TERM

download_repository "$1"
mkdir $BACKUP
learn-ocaml --sync=sync --repo=repository &
PID_INSTANCE=$!

watch_upload "$1" &
PID_WATCH=$!

wait $PID_INSTANCE
