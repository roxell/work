#!/bin/bash

#
# this script builds the kernel using this repo's dir structure
#

CHOICE=$(echo $1 | sed 's:/$::')

OLDDIR=$PWD
MAINDIR=$(dirname $0)
[ "$MAINDIR" == "." ] && MAINDIR=$(pwd)

# VARIABLES (TODO: turn all this into args)

NUMCPU=`cat /proc/cpuinfo | grep proce | wc -l`
NCPU=$(($NUMCPU - 1))
#NCPU=1

MYARCH="amd64"  # (amd64|arm64|armhf|armel)
TOARCH="amd64"  # (amd64|arm64|armhf|armel)

KCROSS=0        # are you cross compiling ? (default: 0)
GCLEAN=1        # want to run git reset ? (default: 1)
KCLEAN=1        # want to run make clean ? (default: 1)
KCONFIG=1       # want to copy and process conf file ? (default: 1)
KMCONFIG=0      # want a menu to add/remove stuff from .config ? (default: 0)
KLCONFIG=0      # want to merge a lsmod file into .config ? (default: 0)
KPREPARE=1      # want to prepare ? (default: 1)
KBUILD=1        # want to build ? :o) (default: 1)
KDEBUG=1        # want your kernel to have debug symbols ? (default: 1)
KVERBOSE=1      # want it to shut up ? (default: 1)

FILEDIR="$HOME/work/files"
MAINDIR="$HOME/work/sources/linux"
TARGET="$HOME/work/build/linux"
KERNELS="$HOME/work/kernels"

LOCKFILE="$MAINDIR/.global.lock"

KRAMFS=1        # TARGET will be a KRAMFSSIZE GB tmpfs (default: 0)
KRAMFSSIZE=20   # TARGET dir size in GB
KRAMFSUMNT=0    # TARGET will be unmounted (default: 0)

ARMHFCONFIG="$FILEDIR/config-armhf"
ARM64CONFIG="$FILEDIR/config-arm64"
AMD64CONFIG="$FILEDIR/config"

DRAGON=0        # dragon board config file (default: 0)
HIKEY=0         # hikey board config file (default: 0)
BEAGLE=0        # beable board config file (default: 0)
OTHER=0         # some other config file (default: 0)

DRAGONCONFIG="$FILEDIR/config-dragon"
HIKEYCONFIG="$FILEDIR/config-hikey"
BEAGLECONFIG="$FILEDIR/config-beagle"
BEAGLELCONFIG="$FILEDIR/lsmod-beagle"
OTHERCONFIG="$FILEDIR/config-other"

# FUNCTIONS

getout() {
    echo ERROR: $@
    exit 1
}

getoutlockup() {
    lockup
    getout $@
}

ctrlc() {
    if [ $KRAMFS != 0 ]; then
        sudo umount $TARGET/$dir
    fi

    lockup
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

# FIXCONFIG

fixconfig()
{
    configfile=$1

    if [ ! -f $configfile ]; then getout "fixconfig: no such config file"; fi

    # DEBUG

    if [ $KDEBUG == 1 ]; then KDB="y"
        sed -i 's/CONFIG_DEBUG_INFO=.*/CONFIG_DEBUG_INFO=y/g' $configfile
        sed -i 's/CONFIG_DEBUG_INFO_DWARF4=.*/CONFIG_DEBUG_INFO_DWARF4=y/g' $configfile
        sed -i 's/^# CONFIG_DEBUG_INFO is/CONFIG_DEBUG_INFO=y/g' $configfile
        sed -i 's/^# CONFIG_DEBUG_INFO_DWARF4 is/CONFIG_DEBUG_INFO_DWARF4=y/g' $configfile
    else
        sed -i 's/CONFIG_DEBUG_INFO=.*/CONFIG_DEBUG_INFO=n/g' $configfile
        sed -i 's/CONFIG_DEBUG_INFO_DWARF4=.*/CONFIG_DEBUG_INFO_DWARF4=n/g' $configfile
        sed -i 's/^# CONFIG_DEBUG_INFO is/CONFIG_DEBUG_INFO=n/g' $configfile
        sed -i 's/^# CONFIG_DEBUG_INFO_DWARF4 is/CONFIG_DEBUG_INFO_DWARF4=n/g' $configfile
    fi

    # NO CERTS

    sed -i 's/^CONFIG_SYSTEM_TRUSTED_KEYRING=.*/CONFIG_SYSTEM_TRUSTED_KEYRING=n/g' $configfile
    sed -i 's/^CONFIG_SYSTEM_TRUSTED_KEYS=.*/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' $configfile

    # ARM

    sed -i 's/CONFIG_GPIO_MOCKUP=.*/CONFIG_GPIO_MOCKUP=m/g' $configfile
    sed -i 's/^# CONFIG_GPIO_MOCKUP.*/CONFIG_GPIO_MOCKUP=m/g' $configfile

    # VIRTIO

    sed -i 's/CONFIG_VIRTIO=.*/CONFIG_VIRTIO=y/g' $configfile
    sed -i 's/CONFIG_VIRTIO_BALLOON=.*/CONFIG_VIRTIO_BALLOON=y/g' $configfile
    sed -i 's/CONFIG_BLK_MQ_VIRTIO=.*/CONFIG_BLK_MQ_VIRTIO=y/g' $configfile
    sed -i 's/CONFIG_SCSI_VIRTIO=.*/CONFIG_SCSI_VIRTIO=y/g' $configfile
    sed -i 's/CONFIG_VIRTIO_BLK=.*/CONFIG_VIRTIO_BLK=y/g' $configfile
    sed -i 's/CONFIG_VIRTIO_CONSOLE=.*/CONFIG_VIRTIO_CONSOLE=y/g' $configfile
    sed -i 's/CONFIG_VIRTIO_INPUT=.*/CONFIG_VIRTIO_INPUT=y/g' $configfile
    sed -i 's/CONFIG_VIRTIO_MENU=.*/CONFIG_VIRTIO_MENU=y/g' $configfile
    sed -i 's/CONFIG_VIRTIO_MMIO=.*/CONFIG_VIRTIO_MMIO=y/g' $configfile
    sed -i 's/CONFIG_VIRTIO_NET=.*/CONFIG_VIRTIO_NET=y/g' $configfile
    sed -i 's/CONFIG_VIRTIO_PCI=.*/CONFIG_VIRTIO_PCI=y/g' $configfile
    sed -i 's/CONFIG_VIRTIO_PCI_LEGACY=.*/CONFIG_VIRTIO_PCI_LEGACY=y/g' $configfile
    sed -i 's/# CONFIG_VIRTIO is.*/CONFIG_VIRTIO=y/g' $configfile
    sed -i 's/# CONFIG_VIRTIO_BALLOON is.*/CONFIG_VIRTIO_BALLOON=y/g' $configfile
    sed -i 's/# CONFIG_BLK_MQ_VIRTIO is.*/CONFIG_BLK_MQ_VIRTIO=y/g' $configfile
    sed -i 's/# CONFIG_SCSI_VIRTIO is.*/CONFIG_SCSI_VIRTIO=y/g' $configfile
    sed -i 's/# CONFIG_VIRTIO_BLK is.*/CONFIG_VIRTIO_BLK=y/g' $configfile
    sed -i 's/# CONFIG_VIRTIO_CONSOLE is.*/CONFIG_VIRTIO_CONSOLE=y/g' $configfile
    sed -i 's/# CONFIG_VIRTIO_INPUT is.*/CONFIG_VIRTIO_INPUT=y/g' $configfile
    sed -i 's/# CONFIG_VIRTIO_MENU is.*/CONFIG_VIRTIO_MENU=y/g' $configfile
    sed -i 's/# CONFIG_VIRTIO_MMIO is.*/CONFIG_VIRTIO_MMIO=y/g' $configfile
    sed -i 's/# CONFIG_VIRTIO_NET is.*/CONFIG_VIRTIO_NET=y/g' $configfile
    sed -i 's/# CONFIG_VIRTIO_PCI is.*/CONFIG_VIRTIO_PCI=y/g' $configfile
    sed -i 's/# CONFIG_VIRTIO_PCI_LEGACY is.*/CONFIG_VIRTIO_PCI_LEGACY=y/g' $configfile

    sed -i 's/CONFIG_BLK_SCSI_REQUEST=.*/CONFIG_BLK_SCSI_REQUEST=y/g' $configfile
    sed -i 's/CONFIG_VIRTIO_BLK_SCSI=.*/CONFIG_VIRTIO_BLK_SCSI=y/g' $configfile
    sed -i 's/CONFIG_SCSI=.*/CONFIG_SCSI=y/g' $configfile
    sed -i 's/CONFIG_SCSI_MOD=.*/CONFIG_SCSI_MOD=y/g' $configfile
    sed -i 's/CONFIG_SCSI_DMA=.*/CONFIG_SCSI_DMA=y/g' $configfile
    sed -i 's/# CONFIG_BLK_SCSI_REQUEST is.*/CONFIG_BLK_SCSI_REQUEST=y/g' $configfile
    sed -i 's/# CONFIG_VIRTIO_BLK_SCSI is.*/CONFIG_VIRTIO_BLK_SCSI=y/g' $configfile
    sed -i 's/# CONFIG_SCSI is.*/CONFIG_SCSI=y/g' $configfile
    sed -i 's/# CONFIG_SCSI_MOD is.*/CONFIG_SCSI_MOD=y/g' $configfile
    sed -i 's/# CONFIG_SCSI_DMA is.*/CONFIG_SCSI_DMA=y/g' $configfile

    # NEEDED

    sed -i 's/CONFIG_EXT4_FS=.*/CONFIG_EXT4_FS=y/g' $configfile
    sed -i 's/# CONFIG_EXT4_FS is .*/CONFIG_EXT4_FS=y/g' $configfile
}


# PREPARE

if [ ! $TOARCH ] && [ $KCROSS != 0 ]; then
    getout "TOARCH: variable not set for CROSS"
fi

if [ $KCROSS == 0 ]; then
    TOARCH=$MYARCH
    CROSS=""
fi

# ARCH TYPE

if [ "$TOARCH" == "armhf" ]; then
    CONFIG=$ARMHFCONFIG
elif [ "$TOARCH" == "arm64" ]; then
    CONFIG=$ARM64CONFIG
elif [ "$TOARCH" == "amd64" ]; then
    CONFIG=$AMD64CONFIG
else
    getout "TOARCH: error"
fi

# BOARD

if [ $DRAGON == 1 ]; then
    CONFIG=$DRAGONCONFIG
    CONFIG=$DRAGONLCONFIG

    if [ "$TOARCH" != "arm64" ]; then
        getout "TOARCH: variable should be arm64 for dragonboard"
    fi

elif [ $BEAGLE == 1 ]; then
    CONFIG=$BEAGLECONFIG
    LCONFIG=$BEAGLELCONFIG

    if [ "$TOARCH" != "armhf" ]; then
        getout "TOARCH: variable should be armhf for beagleboard"
    fi

elif [ $OTHER == 1 ]; then
    CONFIG=$OTHERCONFIG
    CONFIG=$OTHERLCONFIG
fi

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

# BEGIN

lockdown

cd $MAINDIR

[ ! -d $FILEDIR ] && getout "FILEDIR: something went wrong"

DIRS=$(find . -maxdepth 4 -iregex .*/.git | sed 's:\./::g' | sed 's:/.git::g')

for dir in $DIRS; do

    basedir=$(basename $dir)

    [ ! -d $dir ] && getout "DIR: $dir is not a dir ?"

    [ ! -e $dir/.git ] && getout "GIT: $dir/.git does not exist ?"

    [ $CHOICE ] && [ ! "$dir" == "$CHOICE" ] && continue;

    OLDDIR=$(pwd)

    cd $dir

    echo ++++++++ ENTERING $dir ...

    DESCRIBE=$(git describe --long)

    if [ -d $KERNELS/$dir/$DESCRIBE ]; then

        echo "kernel $DESCRIBE already packaged"
        echo -------- CLOSING $dir
        cd $OLDDIR
        continue;

    fi

    ## kernel target ramdisk

    if [ $KRAMFS != 0 ]; then
        # target dir in a ramdisk for faster compilation

        trap "ctrlc" 2

        set -e
        sudo mount -t tmpfs -o size=${KRAMFSSIZE}g tmpfs $TARGET/$dir
        sudo chown -R $USER:$USER $TARGET/$dir
        set +e
    fi

    ## kernel cleanup

    if [ $KCLEAN != 0 ]; then

        if [ $GCLEAN != 0 ]; then gitclean; fi

        make mrproper
        $COMPILE O=$TARGET/$dir clean
    fi

    ## kernel config

    if [ $KCONFIG != 0 ]; then

        [ ! -f $CONFIG ] && getout "$CONFIG is not a valid config file"

        cp $CONFIG $TARGET/$dir/.config
        fixconfig $TARGET/$dir/.config

        CONFIGOPTION="olddefconfig"

        if [ $KMCONFIG != 0 ]; then
            CONFIGOPTION="menuconfig"
        fi

        $COMPILE O=$TARGET/$dir $CONFIGOPTION

        if [ $KLCONFIG != 0 ]; then
            [ ! -f $LCONFIG ] && getout "$LCONFIG is not a valid local config file"
            $COMPILE LSMOD=$LCONFIG O=$TARGET/$dir localmodconfig
        fi
    fi

    ## kernel prepare

    if [ $KPREPARE != 0 ]; then

        $COMPILE O=$TARGET/$dir prepare
        $COMPILE O=$TARGET/$dir scripts
    fi

    ## kernel build

    if [ $KBUILD != 0 ]; then
        # $COMPILE O=$TARGET/$dir zImage
        # $COMPILE O=$TARGET/$dir modules
        # $COMPILE O=$TARGET/$dir modules_install INSTALL_MOD_PATH=$TARGET/$dir/modinstall

        if [ ! -d $KERNELS/$dir/$DESCRIBE ]; then

            # compile if there is no .deb for this kernel

            $COMPILE O=$TARGET/$dir bindeb-pkg ; sync
            DEBS=$(ls -1 $TARGET/$dir/../*.deb | xargs 2>&1 > /dev/null)

            # move .deb packages into proper place

            if [ "$DEBS" != "" ]; then
                mkdir -p "$KERNELS/$dir/$DESCRIBE"
                [ ! -d "$KERNELS/$dir/$DESCRIBE" ] && getout "kernels directory could not be created"
                mv "$TARGET/$dir/../*.deb" "$KERNELS/$dir/$DESCRIBE"
                rm "$TARGET/$dir/../*.{changes,build}"
            fi

        else
            echo "kernel $DESCRIBE already packaged"
        fi
    fi

    ## kernel target ramdisk cleanup

    if [ $KRAMFS != 0 ]; then
        if [ $KRAMFSUMNT != 0 ]; then
            sudo umount $TARGET/$dir
        fi
    fi

    echo -------- CLOSING $dir

    cd $OLDDIR

done

lockup
