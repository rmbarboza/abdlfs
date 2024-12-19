#!/bin/sh

set +h
LFSSCRIPTNAME=${BASH_SOURCE[0]}
SYSTEM_ARCH=$(uname -m)

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
	echo ""
	echo "+---------------------------+"
	echo "|   ERROR: Error trapped!   |"
	echo "+---------------------------+"
	exit -1
}

trap error_trap ERR

check_system()
{
	find / -type f -print |
	egrep -v -e '^/sources|^/tools|^/dev|^/proc|^/sys' |
	while read fname; do cksum $fname; done
}

MKTEST=NO
LD_LIBRARY_PATH=/lib:/usr/lib
export LD_LIBRARY_PATH


echo "#########################################################################"
echo "#####################     Cross compiling tools    ######################"
echo "#####################                              ######################"

cd /sources

# Cross compiler ARCH definition

	if [ "$SYSTEM_ARCH" = "x86_64" ]; then
		CROSS_KARCH=x86
		CROSS_TARGET=i686-pc-linux-gnu
	else
		CROSS_KARCH=x86_64
		CROSS_TARGET=x86_64-pc-linux-gnu
	fi

# Added dev /opt
# Cross Binutils-2.24

	startStep cross-6.12-binutils-2.24

	PATH=$PATH:/opt/cross/bin
	export PATH

	tar -xjf binutils-2.24.tar.bz2; cd binutils-2.24

	mkdir -v ../binutils-build
	cd ../binutils-build

	../binutils-2.24/configure \
		--prefix=/opt/cross \
		--target=$CROSS_TARGET \
		--disable-multilib \
		--disable-nls \
		--disable-werror

	# I think it's possible to use --enable-shared here

	make
	make install

	# Updating the /etc/profile
	( echo
          echo "#included by AbsLFS step cross-6.12-binutils-2.24"
	  echo "export PATH=\$PATH:/opt/cross/bin"
	) >> /etc/profile


	cd ..; rm -rf binutils-2.24; rm -rf binutils-build

# Added dev /opt
# Cross Kernel Header Files

	startStep cross-kernel-headers-"$KERNEL_VERSION"
	tar -xf "$KERNEL_VERSION".tar.xz; cd "$KERNEL_VERSION"

	make ARCH=$CROSS_KARCH INSTALL_HDR_PATH=/opt/cross/$CROSS_TARGET headers_install

	cd ..; rm -rf "$KERNEL_VERSION"

# Added dev /opt
# Cross Gcc-5.2

	startStep "cross-gcc-5.2.0"

	tar -xjf gcc-5.2.0.tar.bz2
	cd gcc-5.2.0

	tar -jxf ../mpfr-3.1.3.tar.bz2
	mv -v mpfr-3.1.3 mpfr
	tar -jxf ../gmp-6.0.0a.tar.bz2
	mv -v gmp-6.0.0 gmp
	tar -zxf ../mpc-1.0.3.tar.gz
	mv mpc-1.0.3 mpc

	mkdir -v ../gcc-build
	cd ../gcc-build

	../gcc-5.2.0/configure \
		--target=$CROSS_TARGET \
		--prefix=/opt/cross \
		--with-glibc-version=2.11 \
		--disable-multilib \
		--enable-languages=c,c++

	make all-gcc
	make install-gcc

# I believe those option will generate a full cross-compiler
#
#		--disable-bootstrap \
#		--disable-libgomp \
#		--disable-libstdcxx-pch \
#		--enable-shared \           # Not 100% sure about enable-shared
#		--with-native-system-header-dir=/opt/cross/$CROSS_TARGET/include \
#		--with-local-prefix=/opt/cross/$CROSS_TARGET/include \
#
#	make
#	make install

	cd ..; rm -rf gcc-5.2.0; rm -rf gcc-build

# Cross glibc-2.22

#
#	missing libgcc, possible build instruction for cross glibc
#
#	startStep "cross-glibc-2.22"
#	tar -xzf glibc-2.22.tar.gz
#	cd glibc-2.22
#
#	mkdir -v ../glibc-build
#	cd ../glibc-build	
#
#	../glibc-2.22/configure  \
#		--prefix=/opt/cross \
#		--host=$CROSS_TARGET  \
#		--build=$(../glibc-2.22/scripts/config.guess) \
#	        --enable-kernel=2.6.32  \
#		--enable-obsolete-rpv \
#		--with-headers=/opt/cross/$CROSS_TARGET/include  \
#		libc_cv_forced_unwind=yes  \
#		libc_cv_ctors_header=yes  \
#		libc_cv_c_cleanup=yes	
#
#	make
#	make install

# Cross tools - strip binaries

	startStep "cross-strip"
	find /opt/cross/bin -type f -exec strip --strip-all '{}' ';'
	find /opt/cross/lib -type f -exec strip --strip-debug '{}' ';'
	for file in cc1 cc1plus collect2 lto1 lto-wrapper
	do
		strip --strip-all /opt/cross/libexec/gcc/$CROSS_TARGET/5.2.0/$file
	done
	
