#!/bin/bash

CHOICE=${1/\/}

OLDDIR=$PWD
MAINDIR=$(dirname $0)
[ "$MAINDIR" == "." ] && MAINDIR=$(pwd)

getout() {
    echo ERROR: $@
    exit 1
}

cd $MAINDIR

#FILEDIR=$(pwd | sed 's:work/sources/.*:work/sources/../files/:g')
#PROJECT=$FILEDIR/project
#CPROJECT=$FILEDIR/cproject

[ ! -d $FILEDIR ] && getout something went wrong

DIRS=$(find . -mindepth 1 -maxdepth 1 -type d | grep -v [a-zA-Z] | xargs)

echo -n > README.md

echo "## bugs.linaro.org" >> README.md

for dir in $DIRS; do

    basedir=$(basename $dir)

    MAINCONTENT="* [BUG $basedir](https://bugs.linaro.org/show_bug.cgi?id=$basedir)"
    echo $MAINCONTENT >> README.md

    [ ! -d $dir ] && getout $dir is not a dir ?

    [ $CHOICE ] && [ ! "$basedir" == "$CHOICE" ] && continue;

    cd $dir
    echo ++++++++ ENTERING $dir ...
    [ -f README.md ] && (cd $MAINDIR; continue;) || echo Creating $basedir/README.md
    CONTENT="[BUG $basedir](https://bugs.linaro.org/show_bug.cgi?id=$basedir)"
    echo $CONTENT > README.md
    echo -------- CLOSING $dir
    cd $MAINDIR

done


cd $OLDDIR

