#!/bin/bash
set -e

cdir=`pwd`
SCRIPTNAME=${BASH_SOURCE[0]}

echo "Starting: $SCRIPTNAME $(date +%Y%m%d-%H%M%S)"

	error_trap() {
		echo -e "   ERROR: Error trapped!   "
		exit -1
	}

	trap error_trap ERR

	Usage()
	{
		echo "Usage: $0 [OPTION] <BASE_CPIO>"
		echo ""
		echo " -h                 Help"
		echo " -karch ARCH        Kernel architecture to compile (x86|x86_64)"
		echo ""
		echo " BASE_CPIO          A cpio.gz file used as base to assemble the final system"
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
					echo "Invalid kernel arch $KARCH (x86_64 or x86)"
					exit -1
				;;
			esac
			;;
		*)
			if [ -z "$LFS_CPIO" ]
			then
				LFS_CPIO=$1; shift
			else
				echo "invalid argument " $(shift)
				exit -1
			fi
			;;
		esac
	done

	if [ -z "$KARCH" -o "$KARCH" = "x86" ]; then
		TGT=i686
	elif [ "$KARCH" = "x86_64" ]; then
		TGT=x86_64
	else
		echo "Unsupported kernel architecture $KARCH"
		exit -1
	fi

	if [ ! -f "$LFS_CPIO" ]; then
		echo "Missing LFS_CPIO: $LFS_CPIO"
		exit -1
	fi

	LFS_CPIO_FULLPATH=$(readlink -e $LFS_CPIO)

	GCCTARGET=`gcc -dumpmachine`
	NEWTARGET=$TGT-pc-linux-gnu

	echo "Cpio image: $LFS_CPIO_FULLPATH"
	echo "Kenrel ARCH: $KARCH"
	echo "Default gcc target: $GCCTARGET"
	echo "New target: $NEWTARGET"

	#sed -i -e '1,$s@/tmp/1.cpio.gz@'$LFS_CPIO_FULLPATH'@' .config
	sed -i -e 's@CONFIG_INITRAMFS_SOURCE=".*"@CONFIG_INITRAMFS_SOURCE="'$LFS_CPIO_FULLPATH'"@' .config

	if ! grep "CONFIG_INITRAMFS_SOURCE=" .config &> /dev/null
	then
		echo "Missing CONFIG_INITRAMFS_SOURCE= from config"
		exit -1
	fi
		

	if [ "$GCCTARGET" != "$NEWTARGET" ]; then
		CROSSGCC=`command -v $NEWTARGET-gcc`
		if [ ! -x "$CROSSGCC" ]; then
			echo "Missing a gcc for target $NEWTARGET"
			exit -1
		fi
		echo "Cross compiling kernel with $CROSSGCC"
		sed -i -e '1,$s@CONFIG_CROSS_COMPILE=".*"@CONFIG_CROSS_COMPILE="'$NEWTARGET'-"@' .config
		# Support for 32 bits executables
		if [ "$TGT" = "x86_64" ]; then
			sed -i -e '1,$s@# CONFIG_IA32_AOUT is not set@CONFIG_IA32_AOUT=y@' .config
			sed -i -e '1,$s@# CONFIG_X86_X32 is not set@CONFIG_X86_X32=y@' .config
		fi
	else
		echo "Using defaut system gcc for target $GCCTARGET"
	fi

	case $KARCH in
		i686) ARCHFLAG="ARCH=x86"
		;;
		x86_64) ARCHFLAG="ARCH=x86_64"
		;;
	esac

	make $ARCHFLAG bzImage

	echo "DONE: $SCRIPTNAME $(date +%Y%m%d-%H%M%S)"

