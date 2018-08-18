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
rm -rf latest/* # && mkdir -p latest/{deb,rpm,txz}

for arch in $(ls -1 | grep -v latest); do

    for pkg in $(ls $arch | grep -v kselftest); do

        deb=$(ls -t1 $arch/$pkg/*.deb 2> /dev/null | head -1)
        rpm=$(ls -t1 $arch/$pkg/*.rpm 2> /dev/null | head -1)
        txz=$(ls -t1 $arch/$pkg/*.txz 2> /dev/null | head -1)

        [ $deb ] && ln -s ../$deb ./latest/$(basename $deb)
        [ $rpm ] && ln -s ../$rpm ./latest/$(basename $rpm)
        [ $txz ] && ln -s ../$txz ./latest/$(basename $txz)

    done
done

cd $OLDDIR
