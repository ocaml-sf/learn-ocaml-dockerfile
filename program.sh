#!/bin/sh
REPOSITORY=repository
SYNC=sync

error() {
    echo "$1 failed" >&2
}

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
        git gc -v
        cd - || error "optimizing_sync: cd - (assert false)" || continue
    done
    git gc
    cd ..
    echo "optimizing done"
}

upload_repository() {
    zip -q $REPOSITORY.zip -r $REPOSITORY
    echo "zipping $REPOSITORY returns $?"
    optimize_sync
    ls -l
    zip -q $SYNC.zip -r $SYNC
    echo "zipping $SYNC returns $?"
    echo "swift upload $1 $REPOSITORY.zip $SYNC.zip"
    swift upload --changed "$1" $REPOSITORY.zip $SYNC.zip
}

trap 'kill -TERM $PID; wait $PID; upload_repository $1; exit 143' TERM

download_repository "$1"
dumb-init learn-ocaml --sync=sync --repo=repository &
PID=$!
wait $PID
