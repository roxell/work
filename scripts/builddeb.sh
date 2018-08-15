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

GLOBALLOCK=$MAINDIR/../.lockfile
LOCKFILE=$MAINDIR/.lockfile

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

lockdown() {
    lockfile-create --lock-name $GLOBALLOCK
    lockfile-create --lock-name $LOCKFILE
}

lockup() {
    lockfile-remove --lock-name $LOCKFILE
    lockfile-remove --lock-name $GLOBALLOCK
    #rm -f $LOCKFILE
    #rm -f $GLOBALLOCK
}

trap "ctrlc" 2
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
cp debian/changelog.initial debian/changelog
fakeroot debian/rules clean

# generate debian package

mkdir /tmp/$$
mkdir -p $WHERETO

PACKAGE=$(ls -1atr ../*_$DEBARCH.deb | tail -1)
[ ! -f $PACKAGE ] && getout "package generation error"
mv $PACKAGE /tmp/$$
[ $? == 0 ] && echo $GITDESC > $WHERETO/.gitdesc

# generate rpm and tgz from deb package

cd /tmp/$$
DEBFILE=$(ls -1 *.deb | tail -1)
[ ! -f $DEBFILE ] && getout "tmp debian package not found"
sudo alien --to-tgz --to-rpm $DEBFILE
sleep 5
RPMFILE=$(ls -1 *.rpm | tail -1)
TGZFILE=$(ls -1 *.tgz | tail -1)
mv $RPMFILE ${DEBFILE/\.deb}.rpm
mv $TGZFILE ${DEBFILE/\.deb}.tgz
mv *.deb $WHERETO
mv *.rpm $WHERETO
mv *.tgz $WHERETO

cd $MAINDIR
rmdir /tmp/$$

gitcleanup

cd $OLDDIR

lockup
