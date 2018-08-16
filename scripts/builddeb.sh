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
    cp debian/changelog.initial debian/changelog
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

[ ! -d .git ] && getout "not a git repo"
[ ! -s debian ] && ln -s $DEBIANIZER/$(basename $PWD) ./debian
[ ! -f debian/changelog.initial ] && getout "no initial changelog"

gitcleanup

# check if a new build is needed

GITDESC=$(git describe --long)
[ $? != 0 ] && getout "git describe error"

[ -f $DESTDIR/$DEBARCH/$(basename $PWD)/.gitdesc ] && \
    OLDGITDESC=$(cat $DESTDIR/$DEBARCH/$(basename $PWD)/.gitdesc) || \
    OLDGITDESC=""

[ "$OLDGITDESC" == "$GITDESC" ] && [ "$CHOICE2" != "force" ] && { lockup ; sync; cleanout "already built"; }

WHERETO=$DESTDIR/$DEBARCH/$(basename $PWD)
[ ! -d $WHERETO ] && getout "dir where to place not found"

# debian generic changelog file

dch -p -v "$(git describe --long)" -D unstable "Upstream commit $(git describe --long)"

# build debian package

fakeroot debian/rules clean
fakeroot debian/rules build
fakeroot debian/rules install
fakeroot debian/rules binary
fakeroot debian/rules clean

# generate debian package

mkdir -p $WHERETO
PACKAGE=$(ls -1atr ../*_$DEBARCH.deb | tail -1)
[ ! -f $PACKAGE ] && echo "package generation error" || echo $PACKAGE generated
mv $PACKAGE $WHERETO 2> /dev/null
[ $? == 0 ] && echo $GITDESC > $WHERETO/.gitdesc

gitcleanup
cd $OLDDIR
lockup
