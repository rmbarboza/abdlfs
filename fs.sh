#!/bin/sh

if [ "$LFS" = "" ]
then
	echo "Set environment variable LFS to root dir of compilated system"
	exit -1
fi

if [ ! -d "$LFS" ]
then
	echo "$LFS" is not a directory
	exit -1
fi

echo "Using LFS: $LFS"

case "$1" in
	mount)
		mount -vt devpts devpts $LFS/dev/pts
		mount -vt tmpfs shm $LFS/dev/shm
		mount -vt proc proc $LFS/proc
		mount -vt sysfs sysfs $LFS/sys
	;;
	umount)
		umount $LFS/dev/pts
		umount $LFS/dev/shm
		umount $LFS/proc
		umount $LFS/sys
	;; 
	*)
		echo "Usage: $0 mount|umount"
	;;
esac


