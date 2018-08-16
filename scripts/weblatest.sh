#!/bin/bash

MAINDIR="/var/www/html"


getout() {
    echo ERROR: $@
    exit 1
}

[ ! -d $MAINDIR ] && getout "no maindir found"

OLDDIR=$PWD
cd $MAINDIR

[ ! -d latest ] && mkdir latest
rm -rf latest/* && mkdir -p latest/{deb,rpm,tgz}

for arch in $(ls -1 | grep -v latest); do

    for pkg in $(ls $arch); do

        deb=$(ls -t1 $arch/$pkg/*.deb 2> /dev/null | head -1)
        rpm=$(ls -t1 $arch/$pkg/*.rpm 2> /dev/null | head -1)
        tgz=$(ls -t1 $arch/$pkg/*.tgz 2> /dev/null | head -1)

        [ $deb ] && ln -s ../../$deb ./latest/deb/$(basename $deb)
        [ $rpm ] && ln -s ../../$rpm ./latest/rpm/$(basename $rpm)
        [ $tgz ] && ln -s ../../$tgz ./latest/tgz/$(basename $tgz)

    done
done

cd $OLDDIR
