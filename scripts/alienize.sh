#!/bin/bash

#
# this script generates rpm and tgz pkgs from deb ones
#

OLDDIR=$PWD
MAINDIR="$HOME/work/pkgs"

mkdir /tmp/$$
cd /tmp/$$

for arch in $(ls -1 $MAINDIR); do
    for pkg in $(ls -1 $MAINDIR/$arch); do
        for deb in $(ls -1 $MAINDIR/$arch/$pkg/*.deb); do
            #
            # $arch/$pkg/$deb
            #

            filename=${deb/\.deb}
            rpm=$filename.rpm
            tgz=$filename.tgz

            if [ ! -f $rpm ]; then
                echo generating $rpm
                sudo alien --to-rpm $deb 2>&1 > /dev/null 2>&1
                tempfile=$(ls -1 *.rpm) 2>&1 > /dev/null 2>&1 && mv $tempfile $filename.rpm
            else
                echo $rpm already exists
            fi

            if [ ! -f $tgz ]; then
                echo generating $tgz
                sudo alien --to-tgz $deb 2>&1 > /dev/null 2>&1
                tempfile=$(ls -1 *.tgz) 2>&1 > /dev/null 2>&1 && mv $tempfile $filename.tgz
            else
                echo $tgz already exists
            fi
        done
    done
done

cd $OLDDIR
rmdir /tmp/$$
