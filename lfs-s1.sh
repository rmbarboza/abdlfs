#!/bin/sh

# LFS 6.5rc2
# LFS 7.6
# LFS 7.8

set +h
umask 022
LFSSCRIPTNAME=${BASH_SOURCE[0]}

echo; echo "AbdLFS: $(date +%Y%m%d-%H%M%S) - Starting $LFSSCRIPTNAME"; echo

CURDIR=`pwd`
LC_ALL=POSIX

if [ "$LFS_TGT" = "" ]
then
	LFS_TGT=$(uname -m)-lfs-linux-gnu
fi

if [ "$WCACHE" = "" ]
then
	echo "Environment var WCACHE not defined"
	exit -1
fi

if [ ! -d "$WCACHE" ]
then
	echo "WCACHE=$WCACHE is not a directory"
	exit -1
fi

PATH=$LFS/tools/bin:$LFS/prereqs/bin:/bin:/usr/bin

export LFS LC_ALL LFS_TGT PATH

startStep() {
        LFSSTEP=$1
        echo
        echo -e "##################################################################"
        echo -e "###  "
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

echo
echo "########################    TOOLCHAIN-PASS1    ##########################"
echo

	echo "Using WCACHE=$WCACHE"
	startStep "MovingFiles"

	mkdir -pv $LFS
	mkdir -pv $LFS/tools
	mkdir -pv $LFS/prereqs
	mkdir -pv $LFS/$LFS

        ln -sv /tools $LFS/$LFS/tools

	# Abud - To be used at next step (lfs-s2.sh)
	echo
	echo ">> Linking  packages in list-sources.txt to sources"
	cp -a lfs-s2.sh $LFS/
	mkdir -pv $LFS/sources
	chmod -v a+wt $LFS/sources
	cat list-sources.txt | while read fname
	do
		trap error_trap ERR
		echo -n $fname"  "
		ln $WCACHE/$fname $LFS/sources
	done
	echo

	# Abud - No more udev
	echo
	echo ">> Moving dev-abud.tar.gz to sources"
	cp dev-abud.tar.gz $LFS/sources

	# Abud - To be used at extensions step (lfs-s3-ext.sh)
	echo
	echo ">> Linking packages in list-extensions.txt to sources"
	cp -a lfs-s3-ext.sh $LFS/
	mkdir -v $LFS/extensions
	chmod -v a+wt $LFS/extensions
	cp -a extensions/* $LFS/extensions/
	cat list-extensions.txt | while read fname
	do
		trap error_trap ERR
		echo -n $fname"  "
		ln $WCACHE/$fname $LFS/extensions
	done
	echo

	# Abud - for use by lfs-s4.sh (dev environ)
	echo
	echo ">> Linking packages in list-dev.txt to sources"
	cp -a lfs-s4.sh $LFS/
	cp -a devsetup $LFS/
	mkdir -v $LFS/sources_dev
	chmod -v a+wt $LFS/sources_dev
	cat list-dev.txt | while read fname
	do
		trap error_trap ERR
		echo -n $fname"  "
		ln $WCACHE/$fname $LFS/sources_dev
	done
	echo

	cd $LFS/sources

echo
echo "########################  PRE-REQUIREMENTS     ##########################"
echo

# Gawk-4.0.2 is required

	startStep "gawk-4.0.2-prereq"
	tar -xzf gawk-4.0.2.tar.gz; cd gawk-4.0.2

	./configure --prefix=$LFS/prereqs
	make
	make install
	
	cd ..; rm -rf gawk-4.0.2

	gawk --version

# Xz-utils is required to open kernel files 3.16.61

	startStep "xz-5.2.2-prereq"
	tar -xzf xz-5.2.2.tar.gz; cd xz-5.2.2
	./configure --prefix=$LFS/prereqs
	make
	make install
	cd ..; rm -rf xz-5.2.2

echo
echo "########################    TOOLCHAIN-PASS1    ##########################"
echo

# 5.4. Binutils-2.19.1
# Upgraded to
# 5.4. Binutils-2.24

	startStep "Binutils-2.24"

	tar -xjf binutils-2.24.tar.bz2
	cd binutils-2.24

	mkdir -v ../binutils-build
	cd ../binutils-build

	../binutils-2.24/configure \
		--prefix=$LFS/tools \
		--target=$LFS_TGT \
		--disable-nls \
		--disable-werror
	make
		#--with-lib-path=$LFS/tools/lib \
		#--with-sysroot=$LFS \
		#--prefix=/tools \
		#--with-lib-path=/tools/lib \

	case $(uname -m) in
		x86_64) mkdir -v $LFS/tools/lib && ln -sv lib $LFS/tools/lib64 ;;
	esac

	make install

	cd ..; rm -rf binutils-2.24; rm -rf binutils-build

# 5.5. Gcc-4.4.1 - Pass 1
# Upgraded to
# 5.5. Gcc-4.9.1 - Pass 1 (just for test)
# Upgraded to
# 5.5. Gcc-5.2.0 - Pass 1

	startStep "gcc-5.2.0.tar.bz2-pass1"

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
		--target=$LFS_TGT \
		--prefix=$LFS/tools \
		--with-glibc-version=2.11 \
		--with-newlib \
		--without-headers \
		--with-local-prefix=$LFS/tools \
		--with-native-system-header-dir=$LFS/tools \
		--disable-nls \
		--disable-shared \
		--disable-multilib \
		--disable-decimal-float \
		--disable-threads \
		--disable-libatomic \
		--disable-libgomp \
		--disable-libquadmath \
		--disable-libssp \
		--disable-libvtv \
		--disable-libstdcxx \
		--enable-languages=c,c++

	make
	make install-strip

	cd ..; rm -rf gcc-5.2.0; rm -rf gcc-build

# pre 5.6 abud tmpperl

	startStep "Abud-tmpperl"
	tar -xzf perl-5.10.0.tar.gz
	cd perl-5.10.0/
	patch -Np1 -i ../perl-5.10.0-consolidated-1.patch
	tmpperldir=$LFS/tools/tmpperl
	sh Configure -des -Dprefix=$tmpperldir -Dvendorprefix=$tmpperldir \
		     -Dman1dir=$tmpperldir/man1 -Dman3dir=$tmpperldir/man3 -Dpager="/usr/bin/less -isR" \
		     -Dlocincpth="/usr/include" \
		     -Dlibpth="/usr/lib"
	make
	make install
	cd ..; rm -rf perl-5.10.0

# 5.6. Linux 2.6.30.2 Api Headers
# Upgraded to
# 5.6. Linux 3.10.104 Api Headers
# Upgraded to
# 5.6. Linux 3.16.61 Api Headers

	startStep "linux-3.16.61.tar.xz - Api-Headers"

	tar -xJf linux-3.16.61.tar.xz

	cd linux-3.16.61

	make mrproper
	make PATH=$tmpperldir/bin:$PATH headers_check
	make PATH=$tmpperldir/bin:$PATH INSTALL_HDR_PATH=dest headers_install
	cp -rv dest/include/* $LFS/tools/include

	cd ..; rm -rf linux-3.16.61

# 5.7. Glibc-2.10.1
# Upgraded to
# 5.7. Glibc-2.20 (test)
# Upgraded to
# 5.7. Glibc-2.22 (test)
# Upgraded to
# 5.7. Glibc-2.23

	startStep "glibc-2.23.tar.gz"

	tar -xzf glibc-2.23.tar.gz
	cd glibc-2.23

	mkdir -v ../glibc-build
	cd ../glibc-build
	
#	case `uname -m` in
#		i?86) echo "CFLAGS += -march=i486 -mtune=native" > configparms ;;
#	esac
	
	../glibc-2.23/configure \
		--prefix=$LFS/tools \
		--host=$LFS_TGT \
		--build=$(../glibc-2.23/scripts/config.guess) \
		--disable-profile \
		--enable-kernel=2.6.32 \
		--enable-obsolete-rpc \
		--with-headers=$LFS/tools/include \
		libc_cv_forced_unwind=yes \
		libc_cv_ctors_header=yes \
		libc_cv_c_cleanup=yes


#		libc_cv_c_cleanup=yes

		#--prefix=$LFS/tools/gcc \
		#--prefix=$LFS/tools \
		#--with-headers=$LFS/tools/include \
	make
	make install

	cd ..; rm -rf glibc-2.23; rm -rf glibc-build


echo
echo "########################    TOOLCHAIN-ADJUST   ##########################"
echo

# 5.8. Adjusting toolchain

	startStep "adjusting-toolchain"


	SPECS=`dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/specs
	$LFS_TGT-gcc -dumpspecs | sed \
		-e 's@/lib\(64\)\?/ld@'$LFS'/tools&@g' \
		-e "/^\*cpp:$/{n;s,$, -isystem $LFS/tools/include,}" > $SPECS
	echo "New specs file is: $SPECS"
	unset SPECS

#		-e 's@/lib\(64\)\?/ld@/lib/gcc/i686-lfs-linux-gnu/4.9.1&@g' \

	LFS_TGT_LIBDIR=$LFS/tools/lib/
	

	(
	  echo '#include <stdio.h>'
	  echo '#include <math.h>'
	  echo 'main(){printf("sin %f\n", (float)sin(1.25 * 3.1415));}'
	) > dummy.c
	$LFS_TGT-gcc -B$LFS_TGT_LIBDIR -o dummy dummy.c
	readelf -l dummy | grep ': '$LFS'/tools'

	rm -v dummy.c dummy


# Libstdc++-4.4.1 
# Upgraded to
# Libstdc++-5.2.0

	startStep "Libstdc++-5.2.0"

	tar -xjf gcc-5.2.0.tar.bz2
	cd gcc-5.2.0

	mkdir -pv ../gcc-build
	cd ../gcc-build

	CC="$LFS_TGT-gcc -B$LFS_TGT_LIBDIR" AR=$LFS_TGT-ar RANLIB=$LFS_TGT-ranlib \
	CXX="$LFS_TGT-g++ -B$LFS_TGT_LIBDIR" \
	../gcc-5.2.0/libstdc++-v3/configure \
	    --host=$LFS_TGT                 \
	    --prefix=$LFS/tools             \
	    --disable-multilib              \
	    --disable-nls                   \
	    --disable-libstdcxx-threads     \
	    --disable-libstdcxx-pch         \
	    --with-gxx-include-dir=$LFS/tools/$LFS_TGT/include/c++/5.2.0

	make
	make install

	cd ..; rm -rf gcc-5.2.0; rm -rf gcc-build

echo
echo "########################    TOOLCHAIN-PASS 2   ##########################"
echo

cd $LFS/sources

# 5.9. Binutils-2.19.1 - Pass 2
# Upgraded to
# 5.9. Binutils-2.24 - Pass 2

	startStep "binutils-2.24.tar.bz2 - Pass2"

	tar -xjf binutils-2.24.tar.bz2
	cd binutils-2.24

	mkdir -v $LFS/sources/binutils-build
	cd $LFS/sources/binutils-build

	#CC="$LFS_TGT-gcc -B$LFS/tools/lib/" \
	CC="$LFS_TGT-gcc -B$LFS_TGT_LIBDIR" AR=$LFS_TGT-ar RANLIB=$LFS_TGT-ranlib \
	../binutils-2.24/configure \
		--prefix=$LFS/tools \
		--disable-nls \
		--disable-werror \
		--with-lib-path=$LFS/tools/lib

	make

	make install

	make -C ld clean
	make -C ld LIB_PATH=/usr/lib:/lib
	cp -v ld/ld-new $LFS/tools/bin

	cd $LFS/sources; rm -rf binutils-2.24; rm -rf binutils-build


# 5.10. GCC-4.4.1 - pass 2
# Upgraded to
# 5.10. GCC-4.9.1 - pass 2 (just for test)
# Upgraded to
# 5.10. GCC-5.2.0 - Pass 2


	startStep "gcc-5.2.0.tar.bz2-pass2"

	tar -xjf gcc-5.2.0.tar.bz2; cd gcc-5.2.0

	tar -jxf ../mpfr-3.1.3.tar.bz2
	mv -v mpfr-3.1.3 mpfr
	tar -jxf ../gmp-6.0.0a.tar.bz2
	mv -v gmp-6.0.0 gmp
	tar -zxf ../mpc-1.0.3.tar.gz
	mv mpc-1.0.3 mpc

	cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
	    `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h

	#trying this from LFS 6.5rc2 --- still works for 4.9.1, checked! abud
        patch -Np1 -i ../gcc-4.4.1-startfiles_fix-1.patch

	for file in \
		$(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h)
	do
		cp -uv $file{,.orig}
		sed -e 's@/lib\(64\)\?\(32\)\?/ld@'$LFS'/tools&@g' \
		    -e 's@/usr@'$LFS'/tools@g' $file.orig > $file
		echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 ""
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
		touch $file.orig
	done

	case $(uname -m) in
	x86_64)
		for file in $(find gcc/config -name t-linux64) ; do \
			cp -v $file{,.orig}
			sed '/MULTILIB_OSDIRNAMES/d' $file.orig > $file
		done
	;;
	esac

	mkdir -v $LFS/sources/gcc-build
	cd $LFS/sources/gcc-build

	CC="$LFS_TGT-gcc  -B$LFS_TGT_LIBDIR" AR=$LFS_TGT-ar RANLIB=$LFS_TGT-ranlib \
	CXX="$LFS_TGT-g++ -B$LFS_TGT_LIBDIR" \
	../gcc-5.2.0/configure \
		--prefix=$LFS/tools \
		--with-local-prefix=$LFS/tools \
		--with-native-system-header-dir=$LFS/tools/include \
		--enable-languages=c,c++ \
		--disable-libstdcxx-pch \
		--enable-clocale=gnu \
		--disable-multilib \
		--disable-bootstrap \
		--disable-libgomp \


	make
	make install

	ln -vs gcc $LFS/tools/bin/cc

	cd $LFS/sources; rm -rf gcc-5.2.0; rm -rf gcc-build


# 5.11. TCL8.5.7

	# Required for for test

	startStep "tcl8.5.7-src.tar.gz"

	tar -xzf tcl8.5.7-src.tar.gz
	cd tcl8.5.7
	cd unix
	./configure --prefix=$LFS/tools
	make
	#TZ=UTC make test
	make install
	chmod -v u+w $LFS/tools/lib/libtcl8.5.so
	make install-private-headers
	ln -sv tclsh8.5 $LFS/tools/bin/tclsh

	cd $LFS/sources; rm -rf tcl8.5.7
	# Ok


# 5.12. Expect-5.43.0

	startStep "expect-5.43.0.tar.gz"

	tar -xzf expect-5.43.0.tar.gz; cd expect-5.43

	patch -Np1 -i ../expect-5.43.0-spawn-1.patch
	patch -Np1 -i ../expect-5.43.0-tcl_8.5.5_fix-1.patch
	cp -v configure{,.orig}
	sed 's:/usr/local/bin:/bin:' configure.orig > configure
	./configure --prefix=$LFS/tools --with-tcl=$LFS/tools/lib --with-tclinclude=$LFS/tools/include --with-x=no
	make
	#make test
	make SCRIPTS="" install

	cd $LFS/sources; rm -rf expect-5.43
	# ok

# 5.13. DejaGNU-1.4.4

	startStep "dejagnu-1.4.4.tar.gz"

	tar -xzf dejagnu-1.4.4.tar.gz; cd dejagnu-1.4.4

	./configure --prefix=$LFS/tools
	make install
	#make check

	cd $LFS/sources; rm -rf dejagnu-1.4.4
	# ok

# 5.14. Ncurses-5.7

	startStep "ncurses-5.7.tar.gz"

	tar -xvf ncurses-5.7.tar.gz; cd ncurses-5.7

	./configure --prefix=$LFS/tools --with-shared --without-debug --without-ada --enable-overwrite
	make
	make install

	cd $LFS/sources; rm -rf ncurses-5.7
	# ok

# 5.15. Bash-4.0
# Upgraded to
# 5.15. Bash-4.4.18

	startStep "bash-4.4.18.tar.gz"

	tar -xzf bash-4.4.18.tar.gz ; cd bash-4.4.18

#	patch -Np1 -i ../bash-4.0-fixes-3.patch
	./configure --prefix=$LFS/tools --without-bash-malloc
	make
	#make tests
	make install
	ln -vs bash $LFS/tools/bin/sh

	cd $LFS/sources; rm -rf bash-4.4.18

# 5.16. Bzip2-1.0.5

	startStep "bzip2-1.0.5.tar.gz"

	tar -xzf bzip2-1.0.5.tar.gz; cd bzip2-1.0.5
	make
	make PREFIX=$LFS/tools install
	cd $LFS/sources; rm -rf bzip2-1.0.5

# 5.17. Coreutils-7.4

	startStep "coreutils-7.4.tar.gz"

	(
	tar -xzf coreutils-7.4.tar.gz; cd coreutils-7.4
	PATH=$tmpperldir/bin:$PATH
	./configure --prefix=$LFS/tools --enable-install-program=hostname
	make
	#make RUN_EXPENSIVE_TESTS=yes check
	make install
	cp -v src/su $LFS/tools/bin/su-tools
	cd $LFS/sources; rm -rf coreutils-7.4
	)

# 5.18. Diffutils-2.8.1

	startStep "diffutils-2.8.1.tar.gz"

	tar -xzf diffutils-2.8.1.tar.gz; cd diffutils-2.8.1
	./configure --prefix=$LFS/tools
	make
	make install
	cd $LFS/sources; rm -rf diffutils-2.8.1

# 5.19. Findutils-4.4.2

	startStep "findutils-4.4.2.tar.gz"

	tar -xzf findutils-4.4.2.tar.gz; cd findutils-4.4.2
	./configure --prefix=$LFS/tools
	make
	#make check
	make install
	cd $LFS/sources; rm -rf findutils-4.4.2

# 5.20. Gawk-3.1.7

	startStep "gawk-3.1.7.tar.bz2"

	tar -xjf gawk-3.1.7.tar.bz2; cd gawk-3.1.7
	./configure --prefix=$LFS/tools
	make
	#make check
	make install
	cd $LFS/sources; rm -rf gawk-3.1.7

# 5.21. Gettext-0.17

	startStep "gettext-0.17.tar.gz"

	tar -xzf gettext-0.17.tar.gz; cd gettext-0.17
	cd gettext-tools
	./configure --prefix=$LFS/tools --disable-shared
	make -C gnulib-lib
	make -C src msgfmt
	cp -v src/msgfmt $LFS/tools/bin
	cd $LFS/sources; rm -rf gettext-0.17

# 5.22. Grep-2.5.4

	startStep "grep-2.5.4.tar.bz2"

	tar -xjf grep-2.5.4.tar.bz2 ; cd grep-2.5.4
	./configure --prefix=$LFS/tools  --disable-perl-regexp --without-included-regex
	make
	make install
	cd $LFS/sources; rm -rf grep-2.5.4

# 5.23. Gzip-1.3.12
# Upgraded to
# 5.23. Gzip-1.6

	startStep "gzip-1.6.tar.gz"
	tar -xzf gzip-1.6.tar.gz; cd gzip-1.6
	./configure --prefix=$LFS/tools
	make
	make install
	cd $LFS/sources; rm -rf gzip-1.6

# 5.24. M4-1.4.13

	startStep "m4-1.4.13.tar.bz2"
	tar -xjf m4-1.4.13.tar.bz2; cd m4-1.4.13
	./configure --prefix=$LFS/tools
	make
	#make check
	make install
	cd $LFS/sources; rm -rf m4-1.4.13

# 5.25. Make-3.81
# Upgraded to
# 5.25. Make-4.0

	startStep "make-4.0.tar.gz"
	tar -xzf make-4.0.tar.gz; cd make-4.0
	./configure --prefix=$LFS/tools
	make
	make install
	cd $LFS/sources; rm -rf make-4.0

# 5.26. Patch-2.5.9

	startStep "patch-2.5.9.tar.gz"
	tar -xzf patch-2.5.9.tar.gz; cd patch-2.5.9
	patch -Np1 -i ../patch-2.5.9-fixes-1.patch
	./configure --prefix=$LFS/tools
	make
	make install
	cd $LFS/sources; rm -rf patch-2.5.9

# 5.27. Perl-5.10.0

	startStep "perl-5.10.0.tar.gz"
	tar -xzf perl-5.10.0.tar.gz ; cd perl-5.10.0
	patch -Np1 -i ../perl-5.10.0-consolidated-1.patch
	sh Configure -des -Dprefix=$LFS/tools -Dstatic_ext='Data/Dumper Fcntl IO POSIX'
	make perl utilities ext/Errno/pm_to_blib
	cp -v perl pod/pod2man $LFS/tools/bin
	mkdir -pv $LFS/tools/lib/perl5/5.10.0
	cp -Rv lib/* $LFS/tools/lib/perl5/5.10.0
	cd $LFS/sources; rm -rf perl-5.10.0


# 5.28. Sed-4.2.1

	startStep "sed-4.2.1.tar.bz2"
	tar -xjf sed-4.2.1.tar.bz2; cd sed-4.2.1
	./configure --prefix=$LFS/tools
	make
	#make check
	make install
	cd $LFS/sources; rm -rf sed-4.2.1

# 5.29. Tar-1.22

	startStep "tar-1.22.tar.bz2"
	tar -xjf tar-1.22.tar.bz2; cd tar-1.22
	./configure --prefix=$LFS/tools
	make
	make install
	cd $LFS/sources; rm -rf tar-1.22

# Abud Xz-5.2.2 (required by lfs-s2.sh)

	startStep xz-5.2.2
	tar -xzf xz-5.2.2.tar.gz; cd xz-5.2.2
	./configure --prefix=$LFS/tools
	make
	make install
	cd $EXTRAS; rm -rf xz-5.2.2

# 5.30. Texinfo-4.13a

	# Abud - no docs - no texinfo

echo
echo "########################    TOOLCHAIN-STRIP    ##########################"
echo

# 5.31. Stripping

	if strip --strip-debug $LFS/tools/lib/*; then echo strip; fi
	if strip --strip-unneeded $LFS/tools/{,s}bin/*; then echo strip; fi
	rm -rf $LFS/tools/{info,man}

# 6.2. Preparing Virtual Kernel File Systems
	mkdir -pv $LFS/{dev,proc,sys}

	mknod -m 600 $LFS/dev/console c 5 1
	mknod -m 666 $LFS/dev/null c 1 3
	mknod $LFS/dev/kvm c 10 232

	#Abud - creating a hardcoded /dev before bind it to host /dev/
	tar -xz -C $LFS/dev -f $LFS/sources/dev-abud.tar.gz

	# Abud - bringing from install_script and missing in dev-abud.tar.gz pack
	mknod -m 640 $LFS/dev/sda3 b 8 3
	mknod -m 640 $LFS/dev/sda4 b 8 4

	mknod -m 640 $LFS/dev/sdb3 b 8 3
	mknod -m 640 $LFS/dev/sdb4 b 8 4

	mknod -m 640 $LFS/dev/sdc b 8 32
	mknod -m 640 $LFS/dev/sdc1 b 8 33
	mknod -m 640 $LFS/dev/sdc2 b 8 34
	mknod -m 640 $LFS/dev/sdc3 b 8 35
	mknod -m 640 $LFS/dev/sdc4 b 8 36

	mknod -m 640 $LFS/dev/sdd b 8 48
	mknod -m 640 $LFS/dev/sdd1 b 8 49
	mknod -m 640 $LFS/dev/sdd2 b 8 50
	mknod -m 640 $LFS/dev/sdd3 b 8 51
	mknod -m 640 $LFS/dev/sdd4 b 8 52

	mknod -m 640 $LFS/dev/vda b 253 0
	mknod -m 640 $LFS/dev/vda1 b 253 1
	mknod -m 640 $LFS/dev/vda2 b 253 2
	mknod -m 640 $LFS/dev/vda3 b 253 3
	mknod -m 640 $LFS/dev/vda4 b 253 4
	mknod -m 640 $LFS/dev/vda5 b 253 5
	mknod -m 640 $LFS/dev/vda6 b 253 6

	mknod -m 640 $LFS/dev/vdb b 253 16
	mknod -m 640 $LFS/dev/vdb1 b 253 17
	mknod -m 640 $LFS/dev/vdb2 b 253 18
	mknod -m 640 $LFS/dev/vdb3 b 253 19
	mknod -m 640 $LFS/dev/vdb4 b 253 20
	mknod -m 640 $LFS/dev/vdb5 b 253 21
	mknod -m 640 $LFS/dev/vdb6 b 253 22

	mkdir $LFS/dev/usb
	mknod -m 666 $LFS/dev/usb/hiddev0 c 180 96
	# 666? Macabro esse device! kkk...

	mknod $LFS/dev/mmcblk0 b 179 0
	mknod $LFS/dev/mmcblk0p1 b 179 1
	mknod $LFS/dev/mmcblk0p2 b 179 2

	ln -s /proc/self/fd ${LFS}/dev/fd

echo
echo "########################    MAINSYSTEM-MKTREE  ##########################"
echo

# 6.5. Creating Directories

	mkdir -pv $LFS/{bin,boot,etc/opt,home,lib,mnt,opt}
	mkdir -pv $LFS/{media/{floppy,cdrom},sbin,srv,var}
	mkdir -pv $LFS/usr/{,local/}{bin,include,lib,sbin,src}
	mkdir -pv $LFS/usr/{,local/}share/{doc,info,locale,man}
	mkdir -v  $LFS/usr/{,local/}share/{misc,terminfo,zoneinfo}
	mkdir -pv $LFS/usr/{,local/}share/man/man{1..8}
	mkdir -v  $LFS/var/{lock,log,mail,run,spool}
	mkdir -pv $LFS/var/{opt,cache,lib/{misc,locate},local}

	install -dv -m 0750 $LFS/root
	install -dv -m 1777 $LFS/tmp $LFS/var/tmp

	for dir in /usr /usr/local; do ln -sv share/{man,doc,info} $LFS$dir; done

	case $(uname -m) in
		x86_64) ln -sv lib $LFS/lib64 && ln -sv lib $LFS/usr/lib64 ;;
	esac


# 6.6. Creating Essential Files and Symlinks


	ln -sv $LFS/tools/bin/{bash,cat,echo,pwd,stty} $LFS/bin
	ln -sv $LFS/tools/bin/perl $LFS/usr/bin
	ln -sv $LFS/tools/lib/libgcc_s.so{,.1} $LFS/usr/lib
	ln -sv $LFS/tools/lib/libstdc++.so{,.6} $LFS/usr/lib
	ln -sv bash $LFS/bin/sh

echo
echo "########################    MAINSYSTEM-FILES   ##########################"
echo

# 6.6. Creating Essential Files and Symlinks

	touch $LFS/etc/mtab

cat > $LFS/etc/passwd << "EOF"
root::0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF

	cat > $LFS/etc/group << "EOF"
root:x:0:
bin:x:1:
sys:x:2:
kmem:x:3:
tty:x:4:
tape:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
mail:x:34:
nogroup:x:99:
EOF

touch $LFS/var/run/utmp $LFS/var/log/{btmp,lastlog,wtmp}

chmod -v 600 $LFS/var/log/btmp 
# group 13 -> expected to be "utmp"
chgrp -v 13 $LFS/var/run/utmp $LFS/var/log/lastlog
chmod -v 664 $LFS/var/run/utmp $LFS/var/log/lastlog

echo; echo "AbdLFS: $(date +%Y%m%d-%H%M%S) - Finished $LFSSCRIPTNAME"; echo
