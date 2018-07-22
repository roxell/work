#!/bin/bash

OLDDIR=$PWD
MAINDIR=$(dirname $0)

getout() {
    echo ERROR: $@
    exit 1
}

gitclone() {
    name=$1
    url=$2
    branch=$3

    echo ====
    echo CLONING: $1

    git submodule add -b $branch -f $url $name
}

cd $MAINDIR

FILE=$(ls -1 1_* | head -1)

[ ! -f $FILE ] && getout no trees file found

while read name url branch
do
    [ -d $name ] && continue
    gitclone $name $url $branch
    
done < $FILE

cd $OLDDIR
