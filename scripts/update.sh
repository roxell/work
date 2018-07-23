#!/bin/bash

CHOICE=$(echo $1 | sed 's:/$::')

OLDDIR=$PWD
MAINDIR=$(dirname $0)
[ "$MAINDIR" == "." ] && MAINDIR=$(pwd)

getout() {
    echo ERROR: $@
    exit 1
}

gitclean() {
    find . -name *.orig -exec rm {} \;
    find . -name *.rej -exec rm {} \;
    git clean -f 2>&1 > /dev/null
    git reset --hard 2>&1 > /dev/null
}

cd $MAINDIR

[ ! -d $FILEDIR ] && getout something went wrong

DIRS=$(find . -maxdepth 4 -iregex .*/.git | sed 's:\./::g' | sed 's:/.git::g')

for dir in $DIRS; do

    basedir=$(basename $dir)

    [ ! -d $dir ] && getout $dir is not a dir ?

    [ ! -e $dir/.git ] && getout $dir/.git does not exist ?

    [ $CHOICE ] && [ ! "$dir" == "$CHOICE" ] && continue;

    cd $dir

    echo ++++++++ ENTERING $dir ...

    git branch | grep -q "HEAD detached" && {
        echo CHECK THIS MANUALLY
        echo -------- CLOSING $dir
        cd $MAINDIR
        continue
    }

    gitclean
    git fetch -a 2>&1 | grep -v "redirecting to"
    BRANCH=$(git branch | grep "*" | sed 's:* ::g')
    ORIGIN=$(git branch -r | grep -v HEAD | grep origin | grep $BRANCH | sed 's: ::g')
    git reset --hard $ORIGIN
    echo -------- CLOSING $dir

    cd $MAINDIR

done

cd $OLDDIR
