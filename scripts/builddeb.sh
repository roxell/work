#!/bin/bash

#
# this script builds a debian package from upstream code
#

CHOICE=$1
MAINDIR=$(dirname $0)/$CHOICE
OLDDIR=$PWD
DESTDIR="$HOME/work/pkgs"
ARCH=$(arch)

getout() {
    echo ERROR: $@
    exit 1
}

cleanout() {
    echo EXIT: $@
    exit 0
}

cd $MAINDIR

[ ! -s debian ] && getout "no debian dir found"
[ ! -f debian/changelog.initial ] && getout "no initial changelog"

# check if a new build is needed

GITDESC=$(git describe --long)
[ $? != 0 ] && getout "git describe error"

[ -f $DESTDIR/$ARCH/$(basename $PWD)/.gitdesc ] && \
    OLDGITDESC=$(cat $DESTDIR/$ARCH/$(basename $PWD)/.gitdesc) || \
    OLDGITDESC=""

[ "$OLDGITDESC" == "$GITDESC" ] && cleanout "already built"

dch -p -v "$(date +%Y%m%d%H%M)-$(git describe --long)" -D unstable "Upstream commit $(git describe --long)"

fakeroot debian/rules clean
fakeroot debian/rules build
fakeroot debian/rules install
fakeroot debian/rules binary
cp debian/changelog.initial debian/changelog
fakeroot debian/rules clean

PACKAGE=$(ls -1atr ../*.deb | tail -1)
ls $PACKAGE
mkdir -p $DESTDIR/$(arch)/$(basename $PWD)
cp $PACKAGE $DESTDIR/$(arch)/$(basename $PWD)/
[ $? == 0 ] && echo $GITDESC > $DESTDIR/$ARCH/$(basename $PWD)/.gitdesc
rm $PACKAGE

cd $OLDDIR
