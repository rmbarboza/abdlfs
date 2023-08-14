#!/bin/sh

set +h
LFSSCRIPTNAME=${BASH_SOURCE[0]}
echo; echo "AbdLFS: $(date +%Y%m%d-%H%M%S) - Starting $LFSSCRIPTNAME"; echo

startStep() {
	LFSSTEP=$1
	echo
	echo -e "##################################################################"
	echo -e "###"
	echo -e "###  AbdLFS: $(date +%Y%m%d-%H%M%S): Starting: $LFSSTEP  ($LFSSCRIPTNAME)"
	echo -e "###"
	echo
}

error_trap() {
	echo -e ""
	echo -e "+---------------------------+"
	echo -e "|   ERROR: Error trapped!   |"
	echo -e "+---------------------------+"
	exit -1
}

trap error_trap ERR

echo "#########################################################################"
echo "#####################                              ######################"
echo "#####################          Opt Squash          ######################"
echo "#####################                              ######################"
echo

PATH=/bin:/sbin:/usr/bin:/usr/sbin

# Opt Squash
# Relevant info: https://www.rootusers.com/gzip-vs-bzip2-vs-xz-performance-comparison/

	startStep Squash-opt-packages

	mkdir -pv /sqsh

	EXTRASDIR=/AbdLFSExtras
	mkdir -pv $EXTRASDIR
	for extra in /opt/*
	do
		if [ -d "$extra" ]; then
			bn=`basename $extra`
			echo "Package $bn"
			mv -v /opt/$bn $EXTRASDIR
		fi
	done
	mksquashfs $EXTRASDIR /sqsh/AbdLFSExtras.sq.img -keep-as-directory -b 16K -comp gzip -Xcompression-level 9 -no-xattrs
	sqshlabel /sqsh/AbdLFSExtras.sq.img "abdlfs_st_extras"
	rm -rf $EXTRASDIR

	startStep Squash-usr

	MOUNTOPTION="ro,suid,dev,exec,auto,nouser,async,loop"
	mksquashfs /usr /sqsh/usr.sq.img -b 16K -comp gzip -Xcompression-level 9 -no-xattrs
	cp /etc/fstab /etc/fstab.orig
	(
		head -1 /etc/fstab.orig;
		echo "/sqsh/usr.sq.img /usr squashfs $MOUNTOPTION 1 1"
		tail -n +2 /etc/fstab.orig
	) > /etc/fstab
	rm -f /etc/fstab.orig
	rm -rf /usr/*

echo; echo "AbdLFS: $(date +%Y%m%d-%H%M%S) - Finished $LFSSCRIPTNAME"; echo
