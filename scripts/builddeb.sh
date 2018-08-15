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

LOCKFILE=$MAINDIR/../.lockfile

[ ! $(which lockfile-create) ] && getout "no lockfile-create"
[ ! $(which lockfile-remove) ] && getout "no lockfile-remove"
export DEBFULLNAME="Rafael David Tinoco"
export DEBEMAIL="rafael.tinoco@linaro.org"
export DEB_BUILD_OPTIONS="parallel=$NCPU nostrip noopt nocheck debug"

getout() {
    lockup
    echo ERROR: $@
    exit 1
}

cleanout() {
    lockup
    echo EXIT: $@
    exit 0
}

gitcleanup() {
    cd $MAINDIR
    git reset --hard
    git clean -fd
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

cd $MAINDIR

[ ! -d .git ] && getout "not a git repo"
[ ! -s debian ] && ln -s $DEBIANIZER/$(basename $PWD) ./debian
[ ! -f debian/changelog.initial ] && getout "no initial changelog"
cp debian/changelog.initial debian/changelog

gitcleanup

# check if a new build is needed

GITDESC=$(git describe --long)
[ $? != 0 ] && getout "git describe error"

[ -f $DESTDIR/$DEBARCH/$(basename $PWD)/.gitdesc ] && \
    OLDGITDESC=$(cat $DESTDIR/$DEBARCH/$(basename $PWD)/.gitdesc) || \
    OLDGITDESC=""

[ "$OLDGITDESC" == "$GITDESC" ] && [ "$CHOICE2" != "force" ] && cleanout "already built"

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
[ ! -f $PACKAGE ] && getout "package generation error"
mv $PACKAGE $WHERETO
[ $? == 0 ] && echo $GITDESC > $WHERETO/.gitdesc

gitcleanup

cd $OLDDIR

lockup
