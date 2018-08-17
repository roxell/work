#!/bin/bash

#
# this script builds a debian package from upstream code
#

NCPU=$(nproc)
DEBARCH=$(dpkg-architecture -qDEB_BUILD_ARCH)

CHOICE=$(basename $1)
CHOICE2=$2

OLDDIR=$PWD
MAINDIR=$HOME/work/sources/trees/$CHOICE
DEBIANIZER="$HOME/work/sources/debianizer/"
DESTDIR="$HOME/work/pkgs"

# global (to machine) lock since this runs inside containers
# only one build (1 container) at a time, it uses all ncpu
# WARN: ONLY ONE BUILD at a time

LOCKFILE=$MAINDIR/../.lockfile

export DEBFULLNAME="Rafael David Tinoco"
export DEBEMAIL="rafael.tinoco@linaro.org"
export DEB_BUILD_OPTIONS="parallel=$NCPU nostrip noopt nocheck debug"

getoutlockup() {
    lockup
    getout $@
}

getout() {
    gitcleanup
    echo ERROR: $@
    exit 1
}

cleanout() {
    echo EXIT: $@
    exit 0
}

gitcleanup() {
    cd $MAINDIR
    git reset --hard
    git clean -fd
    cat debian/changelog.initial > debian/changelog
}

# this is stupid, i know. will fix later
# for this a total racy impl just for testing

lockdown() {

    while true; do
        if [ ! -f $LOCKFILE ]; then
            echo $$ > $LOCKFILE
            sync
            break
        fi

        echo "trying to acquire the lock..."

        # WARN: wait for the lock
        # WARN: 900 second is the min cron interval

        sleep 15
        i=$((i+15))
        if [ $i -eq 900 ]; then
            echo "could not obtain the lock, exiting"
            exit 1
        fi

    done
}

lockup() {
    rm -f $LOCKFILE
    sync
}

lockdown

cd $MAINDIR

# initial checks

[ ! -d .git ] && getoutlockup "not a git repo"
[ ! -s debian ] && ln -s $DEBIANIZER/$(basename $PWD) ./debian
[ ! -f debian/changelog.initial ] && getoutlockup "no initial changelog"

gitcleanup

# checks

GITDESC=$(git describe --long)
[ $? != 0 ] && getoutlockup "git describe error"

WHERETO=$DESTDIR/$DEBARCH/$(basename $PWD)
[ ! -d $WHERETO ] && getoutlockup "dir where to place not found"

OLDGITDESC=""
if [ -f $WHERETO/.gitdesc ]; then
    OLDGITDESC=$(cat $WHERETO/.gitdesc)
fi

# is it already built ?

[ "$OLDGITDESC" == "$GITDESC" ] && [ "$CHOICE2" != "force" ] && {
    lockup ; sync; cleanout "already built";
}

# debian generic changelog file

dch -p -v "$(git describe --long)" -D unstable "Upstream commit $(git describe --long)"

# build debian package

fakeroot debian/rules clean
fakeroot debian/rules build
fakeroot debian/rules install
fakeroot debian/rules binary
sync

# generate debian package

mkdir -p $WHERETO
filename=$(find .. -maxdepth 1 -name *_arm64.deb)
[ $filename ] && filename=$(basename $filename) || filename="nenenene"
find .. -maxdepth 1 -name $filename -exec mv {} $WHERETO/ \;

ls $WHERETO/$filename && {
        echo "$GITDESC generated"
        echo $GITDESC > $WHERETO/.gitdesc
    } || {
        echo "$GITDESC NOT generated"
        echo > $WHERETO/.gitdesc
    }

# clean debian/ and git repo

fakeroot debian/rules clean
gitcleanup
cd $OLDDIR
lockup
