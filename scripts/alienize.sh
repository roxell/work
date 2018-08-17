#!/bin/bash

#
# this script generates rpm and tgz pkgs from deb ones
#

# global to host since only host should run this script
# WARN: dont run this script inside containers

OLDDIR=$PWD
MAINDIR="$HOME/work/pkgs"
LOCKFILE=/tmp/.alienize.lock
TEMPDIR="/tmp/$$"

#
# functions
#

getout() {
    echo ERROR: $@
    exit 1
}

destroytmp() {
    [ -d $TEMPDIR ] && sudo umount $TEMPDIR && sudo rmdir $TEMPDIR || \
        { rm $LOCKFILE ; getout "could not umount temp dir"; }
}

createtmp() {
    sudo mkdir $TEMPDIR || { rm $LOCKFILE ; getout "could not create temp dir"; }
    sudo mount -t tmpfs -o size=3G tmpfs $TEMPDIR || { rm $LOCKFILE ; getout "could not mount temp dir"; }
    sudo chown -R $USER $TEMPDIR
    sync
}

cleantmp() {
    WHEREAMI=$PWD
    cd $OLDDIR
    destroytmp
    createtmp
    cd $WHEREAMI
    sync
}

ctrlc() {
    [ -d $TEMPDIR ] && sudo umount $TEMPDIR 2>&1 > /dev/null 2>&1
    lockup
    exit 1
}

i=0
lockdown() {
    # totally racy locking function

    while true; do
        if [ ! -f $LOCKFILE ]; then
            echo $$ > $LOCKFILE
            sync
            break
        fi

        echo "trying to acquire the lock"

        # wait a bit for the lock
        # WARN: cron should not be less than 120 sec

        sleep 5
        i=$((i+5))
        if [ $i -eq 60 ]; then
            echo "could not obtain the lock, exiting"
            exit 1
        fi

    done
}

lockup() {
    rm -f $LOCKFILE
    sync
}

#
# begin
#

lockdown
trap "ctrlc" 2

# check existing .deb files and see if associated .tgz and .rpm exist
# if not, convert .deb files using alien tool

createtmp
cd $TEMPDIR

for arch in $(ls -1 $MAINDIR); do

    for pkg in $(ls -1 $MAINDIR/$arch); do

        #
        # for each existing .deb package
        #

        for deb in $(ls -1 $MAINDIR/$arch/$pkg/*.deb 2> /dev/null); do

            filename=${deb/\.deb}
            rpm=$filename.rpm
            txz=$filename.txz

            #
            # query info from .deb package
            #

            package=$(dpkg-deb -f $deb Package)
            version=$(dpkg-deb -f $deb Version)
            architecture=$(dpkg-deb -f $deb Architecture)

            if [ "$architecture" == "amd64" ]; then
                altarch="x86_64"
            elif [ "$architecture" == "arm64" ]; then
                altarch="aarch64"
            elif [ "$architecture" == "armhf" ]; then
                altarch="armhfp"
            elif [ "$architecture" == "i386" ]; then
                altarch="i386"
            fi

            # debug:
            #
            # echo $filename
            # echo $package
            # echo $version
            # echo $architecture

            echo $deb being checked...

            # txz

            if [ ! -f $txz ]; then
                echo $tar being generated...
                dpkg -x $deb .
                fpm -C $TEMPDIR -s dir -t tar -n $package .
                tempfile=$(ls -1 *.tar 2>/dev/null) && {
                    tar cvfJ $filename.txz $tempfile
                    rm $tempfile
                } || echo "file $deb was not converted to txz!"

                cleantmp
            else
                echo $tar already generated!
            fi

            # rpm

            if [ ! -f $rpm ]; then
                echo $rpm being generated...
                dpkg -x $deb .
                fpm -C $TEMPDIR -s dir -t rpm -n $package --rpm-compression xz -v $version -a $altarch .
                tempfile=$(ls -1 *.rpm 2>/dev/null) && {
                    mv $tempfile $filename.rpm;
                } || echo "file $deb was not converted to rpm!"

                cleantmp
            else
                echo $rpm already generated!
            fi

        done
    done
done

cd $OLDDIR
destroytmp
lockup
exit 0
