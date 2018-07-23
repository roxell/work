#!/bin/bash

#
# this script updates the git submodules (directories) inside
# a specific directory. without arguments it updates all dirs
#
# this version: updates ALL at once
#

OLDDIR=$PWD
MAINDIR=$(dirname $0)
[ "$MAINDIR" == "." ] && MAINDIR=$(pwd)

getout() {
    echo ERROR: $@
    exit 1
}

cd $MAINDIR

FILES=$(find . -type l -iregex ".*[0-9]*_update.sh")

for file in $FILES; do

    #basedir=$(dirname $file)
    #filename=$(basename $file)

    [ ! -x $file ] && getout $file is not executable ?

    $file

done

cd $OLDDIR
