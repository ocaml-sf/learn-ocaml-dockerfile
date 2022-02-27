#!/bin/sh
BACKUP=backup
REPOSITORY=repository
SYNC=sync

error() {
    echo "$1 failed" >&2
}

# 30 min sleep at beginning
BEGIN=1800
# 10 min sleep interval
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

find_repositories() {
    find "$1" -name .git -exec dirname {} \;
}

optimize_sync() {
    echo "optimizing using git gc"
    for repo in $(find_repositories $SYNC)
    do
        echo "optimizing $repo"
        cd "$repo" || error "optimizing_sync: cd $repo" || continue
        git gc
        cd - || error "optimizing_sync: cd - (assert false)" || continue
    done
    echo "optimizing done"
}

clone_sync() {
    rm -rf ${BACKUP:?}/$SYNC
    echo "cloning sync to avoid concurrency when writing"
    for repo in $(find_repositories $SYNC)
    do
        git clone --config user.name="Learn-OCaml user" "$repo" $BACKUP/"$repo"
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

    sleep $BEGIN &
    PIDSLEEP=$!
    wait $PIDSLEEP
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
