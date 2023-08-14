#!/bin/bash
set -e

# Kernel defaults for this release
KVERSION='3.16.61'
KARCH=x86

cdir=`pwd`
SCRIPTNAME=${BASH_SOURCE[0]}

CVSROOT=`dirname $cdir`
CVSROOT=`dirname $CVSROOT`
WCACHE=$CVSROOT/wcache
HOSTARCH=$(arch)
ABLPATH=$CVSROOT/software/abl

error_trap() {
	echo -e ""
	echo -e "+---------------------------+"
	echo -e "|   ERROR: Error trapped!   |"
	echo -e "+---------------------------+"
	exit -1
}

trap error_trap ERR

echo "Starting: $SCRIPTNAME $(date +%Y%m%d-%H%M%S)"

Usage()
{
	echo "Usage: $0 [OPTION] <CPIO>"
	echo ""
	echo " -abl <DIR>         Path to Abl"
	echo " -c <CONFIG FILE>   Kernel config file to use"
	echo " -kver <VERSION>    Kernel version to use"
	echo " -karch <ARCH>      Kernel architecture to compile(x86 or x86_64)"
	echo " -w <DIR>           Path to DIR/linux-X.Y.Z.tar.xz (wcache)"
	echo ""
	echo " CPIO               A cpio.gz containing system files"
	echo ""
}

	while [ $# -gt 0 ]
	do
		key="$1"
	
		case $key in
		-h|--help)
			Usage
			exit
			;;
		-karch)
			shift
			KARCH=$1; shift
			case $KARCH in
				x86_64|x86) ;;
				*) 
					echo "Invalid kernel arch $KARCH, valids are x86_64 or x86"
					exit
				;;
			esac
			;;
		-abl)
			shift
			ABLPATH=$1; shift
			;;
		-c)
			shift
			CONFIG=$1; shift
			;;
		-w)
			shift
			WCACHE=$1; shift
			;;
		-kver)
			shift
			KVERSION=$1; shift
			;;
		*)
			if [ -z "$LFS_CPIO" ]
			then
				LFS_CPIO=$1; shift
			else
				echo "invalid argument " $(shift)
				Usage
				exit -1
			fi
			;;
		esac
	done

	if [ ! -x $ABLPATH/mkimg.sh ]; then
		echo "Missing ABL at $ABLPATH"
		echo "Could not find $ABLPATH/mkimg.sh"
		exit -1
	fi

	if [ ! -f "$LFS_CPIO" ]; then
		echo "Missing cpio.gz system file ($LFS_CPIO)!"
		Usage
		exit -1
	fi

	LFS_CPIO_FULLPATH=$(readlink -e $LFS_CPIO)

	if [ -z "$CONFIG" ]; then
		CONFIG="kconfig/config.kernel.$KARCH.$KVERSION"
	fi

	if [ ! -f "$CONFIG" ]; then
		echo "Missing kernel config file $CONFIG"
		exit -1
	fi

	if [ ! -d linux-$KVERSION ]; then
		echo "Uncompressing: $WCACHE/linux-$KVERSION.tar.xz"
		tar xf $WCACHE/linux-$KVERSION.tar.xz
	fi

	cp $CONFIG ./linux-$KVERSION/.config
	echo "Using: $CONFIG"

	LFS_BASE_NAME=`basename $LFS_CPIO .cpio.gz`
	LFS_KERNEL_NAME="$LFS_BASE_NAME.k-$KARCH"

	echo "Building kernel with cpio image embedded"
	cd linux-$KVERSION
	$cdir/mkkernel.sh -karch $KARCH $LFS_CPIO_FULLPATH
	BZIMAGE=`pwd`/arch/x86/boot/bzImage
	# Boot loader
	cd $cdir

	echo "Making bootable image."
	cd $ABLPATH
	make
	./mkimg.sh -f $BZIMAGE -o $cdir
	cd $cdir

	echo "Image name: $LFS_KERNEL_NAME.img"
	mv -v system.img $LFS_KERNEL_NAME.img

	echo "kernel name: $LFS_KERNEL_NAME.bzImage"
	mv -v $BZIMAGE $LFS_KERNEL_NAME.bzImage

	echo "Converting to VMDK Disk: $LFS_KERNEL_NAME.vmdk"
	qemu-img convert -f raw -O vmdk $LFS_KERNEL_NAME.img $LFS_KERNEL_NAME.vmdk
	
	echo "GZIPing raw image to $LFS_KERNEL_NAME.img.gz"
	rm -f $LFS_KERNEL_NAME.img.gz
	gzip $LFS_KERNEL_NAME.img
	
	echo "DONE: $SCRIPTNAME $(date +%Y%m%d-%H%M%S)"
