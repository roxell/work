#!/bin/bash

MAINDIR="/var/www/html"

[ ! -d $MAINDIR ] && { echo "no maindir found" ; exit 1 }

OLDDIR=$PWD
cd $MAINDIR

[ ! -d latest ] && mkdir latest
rm -f latest/*

for arch in $(ls -1 | grep -v latest); do
    for pkg in $(ls $arch); do

        deb=$(ls -t1 $arch/$pkg/*.deb 2> /dev/null)
        rpm=$(ls -t1 $arch/$pkg/*.rpm 2> /dev/null)
        tgz=$(ls -t1 $arch/$pkg/*.tgz 2> /dev/null)

        [ $deb ] && ln -s ../$deb ./latest/$(basename $deb)
        [ $rpm ] && ln -s ../$rpm ./latest/$(basename $rpm)
        [ $tgz ] && ln -s ../$tgz ./latest/$(basename $tgz)
    done
done

cd $OLDDIR
