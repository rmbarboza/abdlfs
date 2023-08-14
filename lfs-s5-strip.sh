#!/bin/sh

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

if [ D"$1" = D"dev" ]
then
	dev=yes
else
	if [ D"$1" = D"pro" ]
	then
		dev=no
	else
		echo "Usage: $0 dev|pro"
		exit
	fi
fi

if [ D"$LFS" = "D" ]
then
	echo "You need to set "'$LFS'
	exit -1
fi

if [ "$dev" = no ]
then
	startStep "strip-pro"
else
	startStep "strip-dev"
fi

# Removing toolchain
rm -rf $LFS/tools
rm -rf $LFS/reqs
rm -rf $LFS/prereqs
rm -rf $LFS/devsetup

# need to remove $LFS/$LFS/tools

# Removing sources
rm -rf $LFS/sources_dev
rm -rf $LFS/sources
rm -rf $LFS/extensions

# Removing scripts
rm -rf $LFS/lfs-s2.sh
rm -rf $LFS/lfs-s3-ext.sh
rm -rf $LFS/lfs-s4.sh

# Removing docs and gcc and opt
if [ "$dev" = no ]
then
	# Removing man
	rm -rf $LFS/usr/include

	# Removing gcc keeping libraries !
	sort $LFS/installlogs/cksum.gcc.after.txt > /tmp/after.sort.txt
	sort $LFS/installlogs/cksum.gcc.before.txt > /tmp/before.sort.txt
	diff /tmp/before.sort.txt /tmp/after.sort.txt |
	egrep -e '^>'| awk '{ print $4 }' |
	while read file
        do
		b=`dirname $file`
		if [ "$b" != "/usr/lib" ]
		then
			rm -f $LFS/$file
		fi
	done
	rm -f /tmp/after.sort.txt
	rm -f /tmp/before.sort.txt

	# Removing static libs
	rm -f $LFS/lib/*.a $LFS/usr/lib/*.a $LFS/usr/local/lib/*.a

	# Removing docs and vim stuff
	rm -rf $LFS/usr/share/info/*
	rm -rf $LFS/usr/share/doc/*
	rm -rf $LFS/usr/share/man/*

	# Removing vim stuff
	rm -rf $LFS/usr/share/vim/vim72/spell
fi

# clean /usr/share
rm -rf $LFS/usr/share/gtk-doc
rm -rf $LFS/usr/share/info
rm -rf $LFS/usr/share/vim/vim72/doc
rm -rf $LFS/usr/share/vim/vim72/tutor

# clean /usr/share/doc
rm -rf $LFS/usr/share/doc/groff-1.20.1
rm -rf $LFS/usr/share/doc/libxml2-2.7.8
rm -rf $LFS/usr/share/doc/bzip2-1.0.5
rm -rf $LFS/usr/share/doc/libxslt-1.1.20
rm -rf $LFS/usr/share/doc/valgrind
rm -rf $LFS/usr/share/doc/bash-4.4.18

# clean /usr/share/man
if [ -d $LFS/usr/share/man ]
then
(
	cd $LFS/usr/share/man
	du -sk * | grep -v cat | grep -v man | cut -f 2 | while read d; do rm -rf $d; done
)
fi

# Removing locale
rm -rf $LFS/usr/share/locale/*/LC_MESSAGES/*

# Clearing /tmp
rm -rf $LFS/tmp/*

# Install logs
rm -rf $LFS/installlogs

rm -f $LFS/usr/local/sbin/babeld
rm -f $LFS/usr/local/sbin/isisd
rm -f $LFS/usr/local/sbin/ripd
rm -f $LFS/usr/local/sbin/ripngd
rm -f $LFS/usr/local/sbin/watchquagga
rm -f $LFS/usr/local/sbin/zebra


echo; echo "AbdLFS: $(date +%Y%m%d-%H%M%S) - Finished $LFSSCRIPTNAME"; echo
