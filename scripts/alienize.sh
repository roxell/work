#!/bin/bash

#
# this script generates rpm and tgz pkgs from deb ones
#

LOCKFILE=/tmp/alienize.lock

getout() {
    echo ERROR: $@
    exit 1
}

ctrlc() {
    lockup
}

# this is stupid, i know. will fix later
# for this a total racy impl just for testing

lockdown() {
    while true; do
        if [ ! -f $LOCKFILE ]; then
            touch $LOCKFILE
            break
        fi
        sleep 3
    done
}

lockup() {
    if [ -f $LOCKFILE ]; then
        rm $LOCKFILE
    else
        getout "my lock disappeared =)"
    fi
}

trap "ctrlc" 2
lockdown

OLDDIR=$PWD
MAINDIR="$HOME/work/pkgs"

mkdir /tmp/$$
cd /tmp/$$

for arch in $(ls -1 $MAINDIR); do
    for pkg in $(ls -1 $MAINDIR/$arch); do
        for deb in $(ls -1 $MAINDIR/$arch/$pkg/*.deb); do

            filename=${deb/\.deb}
            rpm=$filename.rpm
            tgz=$filename.tgz

            # rpm

            if [ ! -f $rpm ]; then
                echo generating $rpm
                sudo alien --to-rpm $deb 2>&1 > /dev/null 2>&1
                tempfile=$(ls -1 *.rpm 2>/dev/null)
                if [ -f $tempfile ]; then
                    mv $tempfile $filename.rpm
                else
                    getout "does $tempfile exist ?"
                fi
            else
                echo $rpm already exists
            fi

            # tgz

            if [ ! -f $tgz ]; then
                echo generating $tgz
                sudo alien --to-tgz $deb 2>&1 > /dev/null 2>&1
                tempfile=$(ls -1 *.tgz 2>/dev/null)
                if [ -f $tempfile ]; then
                    mv $tempfile $filename.tgz
                else
                    getout "does $tempfile exist ?"
                fi
            else
                echo $tgz already exists
            fi

        done
    done
done

cd $OLDDIR
rmdir /tmp/$$

lockup
