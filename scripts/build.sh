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

KCROSS=1        # are you cross compiling ? (default: 0)
GCLEAN=1        # want to run git reset ? (default: 1)
KCLEAN=1        # want to run make clean ? (default: 1)
KCONFIG=1       # want to copy and process conf file ? (default: 1)
KPREPARE=1      # want to prepare ? (default: 1)
KBUILD=1        # want to build ? :o) (default: 1)
KSELFTESTS=0    # want to build and generate kselftests .tar.gz ? (default: 0)
KDEBUG=1        # want your kernel to have debug symbols ? (default: 0)
KVERBOSE=1      # want it to shut up ? (default: 1)

MYARCH="amd64"  # (amd64|arm64|armhf|armel)
TOARCH="armhf"  # (amd64|arm64|armhf|armel)

FILEDIR=$(pwd | sed 's:work/sources/.*:work/sources/../files/:g')
MAINDIR=$(pwd | sed 's:work/sources/.*:work/sources/../sources/linux:g')
TARGET=$(pwd | sed 's:work/sources/.*:work/sources/../build/linux:g')
KERNELS=$(pwd | sed 's:work/sources/.*:work/sources/../kernels:g')

KRAMFS=1        # TARGET will be a KRAMFSSIZE GB tmpfs
KRAMFSSIZE=12   # TARGET dir size in GB

ARMHFCONFIG="$FILEDIR/config-armhf"
ARM64CONFIG="$FILEDIR/config-arm64"
AMD64CONFIG="$FILEDIR/config"

DRAGON=0        # dragon board config file (default: 0)
HIKEY=0         # hikey board config file (default: 0)
BEAGLE=0        # beable board config file (default: 0)
OTHER=0         # some other config file (default: 0)

DRAGONCONFIG="$FILEDIR/config-dragon"
HIKEYCONFIG="$FILEDIR/config-dragon"
BEAGLECONFIG="$FILEDIR/config-dragon"
OTHERCONFIG="$FILEDIR/config-other"

# FUNCTIONS

ctrlc() {
    if [ $KRAMFS != 0 ]; then
        sudo umount $TARGET/$dir
    fi
}

getout() {
    echo ERROR: $@
    exit 1
}

gitclean() {
    find . -name *.orig -exec rm {} \;
    find . -name *.rej -exec rm {} \;
    git clean -f 2>&1 > /dev/null
    git reset --hard 2>&1 > /dev/null
}

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

if [ "$KSELFTESTS" != 0 ]; then
    echo -n "kselftests require userland libs/headers! press any key..."
    read
fi

if [ ! $TOARCH ] && [ $KCROSS != 0 ]; then
    getout "TOARCH: variable not set for CROSS"
fi

if [ $KCROSS == 0 ]; then
    TOARCH=$MYARCH
    CROSS=""
fi

if [ "$TOARCH" == "armhf" ]; then
    CONFIG=$ARMHFCONFIG
elif [ "$TOARCH" == "arm64" ]; then
    CONFIG=$ARM64CONFIG
elif [ "$TOARCH" == "amd64" ]; then
    CONFIG=$AMD64CONFIG
else
    getout "TOARCH: error"
fi

if [ $DRAGON == 1 ]; then
    CONFIG=$DRAGONCONFIG
    if [ "$TOARCH" != "arm64" ]; then
        getout "TOARCH: variable should be arm64 for dragonboards"
    fi
elif [ $OTHER == 1 ]; then
    CONFIG=$OTHERCONFIG
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

COMPILE="make ARCH=$TOARCH V=$KVERBOSE -j$NCPU"

if [ $KCROSS == 0 ]; then
    COMPILE="make V=$KVERBOSE -j$NCPU"
fi

if [ $CROSS ]; then
    COMPILE="$COMPILE CROSS_COMPILE=$CROSS"
fi

# BEGIN

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

    DESCRIBE=$(git describe)

    if [ $KRAMFS != 0 ]; then
        # target dir in a ramdisk for faster compilation

        trap "ctrlc" 2

        set -e
        sudo mount -t tmpfs -o size=${KRAMFSSIZE}g tmpfs $TARGET/$dir
        sudo chown -R $USER:$USER $TARGET/$dir
        set +e
    fi

    if [ $KCLEAN != 0 ]; then

        if [ $GCLEAN != 0 ]; then gitclean; fi

        make mrproper
        $COMPILE O=$TARGET/$dir clean
    fi

    if [ $KCONFIG != 0 ]; then

        cp $CONFIG $TARGET/$dir/.config
        fixconfig $TARGET/$dir/.config
        # $COMPILE O=$TARGET/$dir menuconfig
        $COMPILE O=$TARGET/$dir olddefconfig
    fi

    if [ $KPREPARE != 0 ]; then

        $COMPILE O=$TARGET/$dir prepare
        $COMPILE O=$TARGET/$dir scripts
    fi

    if [ $KBUILD != 0 ]; then
        true
        # $COMPILE O=$TARGET/$dir zImage
        # $COMPILE O=$TARGET/$dir modules
        # $COMPILE O=$TARGET/$dir modules_install INSTALL_MOD_PATH=$TARGET/$dir/modinstall
        $COMPILE O=$TARGET/$dir bindeb-pkg

        # move
        mkdir -p $KERNELS/$dir/$DESCRIBE
        [ ! -d $KERNELS/$dir/$DESCRIBE ] && getout "kernels directory could not be created"
        mv $TARGET/$dir/../*.deb $KERNELS/$dir/$DESCRIBE
    fi

    if [ $KSELFTESTS != 0 ]; then

        if [ $KCROSS != 0 ]; then
            echo "kselftests can't cross-compile. do it in a lxc container!"
            exit 1
        fi

        # kselftests generation

        # $COMPILE -C tools clean
        # $COMPILE -C tools gpio
        # $COMPILE -C tools selftests
        # $COMPILE -C tools/testing/selftests TARGETS=gpio all
        # $COMPILE -C tools/testing/selftests TARGETS=zram all
        $COMPILE -C tools/testing/selftests clean
        $COMPILE -C tools/testing/selftests all

        tar cfz $TARGET/$dir/tools.tar.gz ./tools

        # move
        mkdir -p $KERNELS/$dir/$DESCRIBE
        [ ! -f $TARGET/$dir/tools.tar.gz ] && getout "tools not created"
        [ ! -d $KERNELS/$dir/$DESCRIBE ] && getout "kernels directory could not be created"
        mv $TARGET/$dir/tools.tar.gz $KERNELS/$dir/$DESCRIBE
    fi

    # if [ $KCLEAN != 0 ] && [ $GCLEAN != 0 ]; then gitclean; fi

    if [ $KRAMFS != 0 ]; then
        sudo umount $TARGET/$dir
    fi


    echo -------- CLOSING $dir

    cd $OLDDIR

done
