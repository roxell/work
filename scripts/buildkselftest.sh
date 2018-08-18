#!/bin/bash

#
# this script builds kselftest using this repo's dir structure
#

CHOICE=$(echo $1 | sed 's:/$::')

OLDDIR=$PWD
FILEDIR="$HOME/work/files"
MAINDIR="$HOME/work/sources/linux"
TEMPDIR="/tmp/$$"

# VARIABLES (TODO: turn all this into args)

NUMCPU=`cat /proc/cpuinfo | grep proce | wc -l`
NCPU=$(($NUMCPU - 1))
                                             # pick your poison:
MYARCH=$(dpkg-architecture -qDEB_BUILD_ARCH) # (amd64|arm64|armhf|armel)
TOARCH=$MYARCH                               # (amd64|arm64|armhf|armel)

KCROSS=0
if [ "$TOARCH" != "$MYARCH" ]; then
    KCROSS=1
fi

KVERBOSE=1      # want it to shut up ? (default: 1)

# FUNCTIONS

getout() {
    echo ERROR: $@
    exit 1
}

getoutlockup() {
    lockup
    getout $@
}

destroytmp() {
    [ -d $TEMPDIR ] && sudo umount $TEMPDIR && sudo rmdir $TEMPDIR || \
        { rm -f $LOCKFILE ; getout "could not umount temp dir"; }
}

createtmp() {
    sudo mkdir $TEMPDIR || { rm -f $LOCKFILE ; getout "could not create temp dir"; }
    sudo mount -t tmpfs -o size=1G tmpfs $TEMPDIR || { rm -f $LOCKFILE ; getout "could not mount temp dir"; }
    sudo chown -R $USER $TEMPDIR
}

cleantmp() {
    WHEREAMI=$PWD
    cd $OLDDIR
    destroytmp
    createtmp
    cd $WHEREAMI
}

ctrlc() {
    [ -d $TEMPDIR ] && sudo umount $TEMPDIR 2>&1 > /dev/null 2>&1
}

gitclean() {
    find . -name *.orig -exec rm {} \;
    find . -name *.rej -exec rm {} \;
    git clean -fd 2>&1 > /dev/null
    git reset --hard 2>&1 > /dev/null
}

# LOCKS

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

# CROSS

if [ $KCROSS != 0 ]; then
    if [ "$TOARCH" == "armhf" ]; then
        CROSS="arm-linux-gnueabihf-"
        TOARCH="arm"
    elif [ "$TOARCH" == "armel" ]; then
        CROSS="arm-linux-gnueabi-"
        TOARCH="arm"
    elif [ "$TOARCH" == "arm64" ]; then
        CROSS="aarch64-linux-gnu-"
    else
        getout "TOARCH: wrong arch"
    fi
fi

# COMPILE FLAGS

COMPILE="make ARCH=$TOARCH V=$KVERBOSE -j$NCPU"

if [ $KCROSS == 0 ]; then
    COMPILE="make V=$KVERBOSE -j$NCPU"
fi

if [ $CROSS ]; then
    COMPILE="$COMPILE CROSS_COMPILE=$CROSS"
fi

# PACKAGE WILL BE PLACED

TARGET="$HOME/work/pkgs/$TOARCH/kselftest"
[ ! -d $TARGET ] && mkdir -p $TARGET

# BEGIN

trap "ctrlc" 2
createtmp

cd $MAINDIR

[ ! -d $FILEDIR ] && getout "FILEDIR: something went wrong"

# don't include stable-rc automatically

if [ "$CHOICE" == "" ]; then
    DIRS=$(find . -maxdepth 4 -iregex .*/.git -not -iregex .*stable-rc/stable-rc.* | sed 's:\./::g' | sed 's:/.git::g')
else
    DIRS=$(find . -maxdepth 4 -iregex .*/.git | sed 's:\./::g' | sed 's:/.git::g')
fi

# iterate all dirs

for dir in $DIRS; do

    basedir=$(basename $dir)

    [ ! -d $dir ] && getout "ERROR: $dir is not a dir ?"

    [ ! -e $dir/.git ] && getout "ERROR: $dir/.git does not exist ?"

    [ $CHOICE ] && [ ! "$dir" == "$CHOICE" ] && continue;

    OLDDIR=$(pwd)

    LOCKFILE="$dir/.local.lock"

    lockdown
    cd $dir
    echo ++++++++ ENTERING $dir ...

    gitclean

    DESCRIBE=$(git describe --long)

    ## kernel selftests

    if [ $KCROSS != 0 ]; then
        echo "ERROR: kselftest can't cross-compile. use lxc!"
        exit 1
    fi

    # kselftests generation

    # examples:
    #
    # $COMPILE -C tools clean
    # $COMPILE -C tools gpio
    # $COMPILE -C tools selftests
    # $COMPILE -C tools/testing/selftests TARGETS=gpio all
    # $COMPILE -C tools/testing/selftests TARGETS=zram all
    # $COMPILE -C tools/testing/selftests clean

    if [ ! -f $TARGET/kselftest-$DESCRIBE.txz ]; then

        # generating a new .txz file

        echo "INFO: kselftest $DESCRIBE being generated."

        $COMPILE -C tools clean
        CFLAGS="-fPIC" $COMPILE -C tools/testing/selftests all
        RET=$?

        # TODO: check for compilation errors

        if [ $RET -eq 0 ]; then
            tar cfJ $TARGET/kselftest-$DESCRIBE.txz ./tools
            ls $TARGET/kselftest-$DESCRIBE.txz
            [ ! -f $TARGET/kselftest-$DESCRIBE.txz ] && echo "ERROR: kselftest $DESCRIBE not created."
        else
            echo "ERROR: kselftest $DESCRIBE could not be compiled."
        fi

        gitclean
    else
        # no need to re-generate

        echo "INFO: kselftest-$DESCRIBE already exists"
    fi

    echo -------- CLOSING $dir
    cd $OLDDIR
    lockup

    cleantmp
done

cd $OLDDIR
destroytmp
lockup
exit 0
