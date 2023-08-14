#!/bin/sh

#	http://ftp.gnu.org/gnu/cpio/cpio-2.11.tar.gz

# Relevant note:
#
# Most large packages like Perl, Python, CMake, llvm and alike should no go into
# specific dir at /opt.
#
# Using general format /opt/<toolname><major version>
#
# Examples:
# Perl5 -> /opt/perl5
# Python3 -> /opt/python3

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

	startStep cross-kernel-headers-3.16.61
	tar -xf linux-3.16.61.tar.xz; cd linux-3.16.61

	make ARCH=$CROSS_KARCH INSTALL_HDR_PATH=/opt/cross/$CROSS_TARGET headers_install

	cd ..; rm -rf linux-3.16.61

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
	
echo "#########################################################################"
echo "#####################          Delayed S2          ######################"
echo "#####################   Extensions for Dev Image   ######################"

cdir=/sources_dev
cd $cdir

# 6.42. Groff-1.20.1

	startStep groff-1.20.1
	tar -xzf groff-1.20.1.tar.gz; cd groff-1.20.1
	PAGE=A4 ./configure --prefix=/usr
	make
	make docdir=/usr/share/doc/groff-1.20.1 install
	ln -sv eqn /usr/bin/geqn
	ln -sv tbl /usr/bin/gtbl
	cd $cdir; rm -rf groff-1.20.1

# 6.48. Man-DB-2.5.5

	startStep Man-DB-2.5.5
	tar -xzf man-db-2.5.5.tar.gz ; cd man-db-2.5.5

	patch -Np1 -i ../man-db-2.5.5-fix_testsuite-1.patch

	./configure --prefix=/usr --libexecdir=/usr/lib \
		--sysconfdir=/etc --disable-setuid \
		--with-browser=/usr/bin/lynx --with-vgrind=/usr/bin/vgrind \
		--with-grap=/usr/bin/grap
	
		make

	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check
	fi

	make install

	cd $cdir; rm -rf man-db-2.5.5

# Added dev /opt 
# 5.27. Perl-5.10.0

	startStep perl-5.10.0
	rm -f /usr/bin/perl
	mkdir -pv /opt/perl5

	PATH=$PATH:/opt/perl5/bin
	LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/perl5/lib
	export PATH LD_LIBRARY_PATH

	tar -xzf perl-5.10.0.tar.gz ; cd perl-5.10.0

	sed -i -e "s|BUILD_ZLIB\s*= True|BUILD_ZLIB = False|"           \
	       -e "s|INCLUDE\s*= ./zlib-src|INCLUDE    = /usr/include|" \
	       -e "s|LIB\s*= ./zlib-src|LIB        = /usr/lib|"         \
		ext/Compress/Raw/Zlib/config.in
	sh Configure -des \
		-Dprefix=/opt/perl5 \
		-A "append:ccflags=-Wno-unused-but-set-variable" \
		-Dpager="/usr/bin/less -isR"

	make
	make install

	# Links for usual #!/usr/bin/perl shebang, Abud
	rm -f /usr/bin/perl
	ln -s /opt/perl5/bin/perl /usr/bin/perl
	ln -s /opt/perl5/bin/perl /usr/bin/perl5

	# Updating /etc/man_db.conf
	echo "MANDATORY_MANPATH		/opt/perl5/man" >> /etc/man_db.conf
	echo "MANDB_MAP		/opt/perl5/man	/var/cache/man" >> /etc/man_db.conf

	# Updating the /etc/profile
	( echo
          echo "#included by AbsLFS step perl-5.10.0"
	  echo "export PATH=\$PATH:/opt/perl5/bin"
	  echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/opt/perl5/lib"
	) >> /etc/profile

	cd $cdir; rm -rf perl-5.10.0

# Cpio-2.11

	startStep cpio-2.11
	tar -xzf cpio-2.11.tar.gz; cd cpio-2.11
	# Abud: glibc warning about gets 
	sed -i -e '/gets is a/d' gnu/stdio.in.h
	./configure --prefix=/usr
	make
	make install
	cd $cdir; rm -rf cpio-2.11

# SVN

	startStep SVN-1.6.16

	tar -xzf apr-1.4.5.tar.gz ; cd apr-1.4.5
	./configure --prefix=/usr
	make
	make install
	cd $cdir; rm -rf apr-1.4.5

	tar -xzf apr-util-1.3.12.tar.gz ; cd apr-util-1.3.12
	./configure --prefix=/usr --with-apr=/usr
	make
	make install
	cd $cdir; rm -rf apr-util-1.3.12

	tar -xzf libxml2-sources-2.7.8.tar.gz ; cd libxml2-2.7.8 
	./configure --prefix=/usr
	#ignore this error "/bin/rm: cannot remove `libtoolT': No such file or directory"
	make
	make install
	cd $cdir; rm -rf libxml2-2.7.8

	tar -xzf neon-0.29.6.tar.gz ; cd neon-0.29.6
	./configure --prefix=/usr
	make
	make install
	cd $cdir; rm -rf neon-0.29.6

	tar -xzf sqlite-autoconf-3070603.tar.gz ; cd sqlite-autoconf-3070603
	./configure --prefix=/usr
	make
	make install
	cd $cdir; rm -rf sqlite-autoconf-3070603

	tar -xzf subversion-1.6.16.tar.gz ; cd subversion-1.6.16
	./configure --prefix=/usr
	make
	make install
	cd $cdir; rm -rf subversion-1.6.16

# Added 20230812
# Git-2.1.0

	startStep git-2.1.0
	tar -xf git-2.1.0.tar.xz ; cd git-2.1.0
	sed -i "/BSD_SOURCE/d" git-compat-util.h
	# Adding /tools/bin to access msgfmt from toolchain gettext:w
	SAVEDPATH=$PATH
	export PATH=$PATH:/tools/bin
	./configure --prefix=/usr --with-gitconfig=/etc/gitconfig
	make
	make install
	export PATH=$SAVEDPATH
	cd $cdir; rm -rf git-2.1.0

# CTAGS

	startStep ctags-5.8
	tar -xzf ctags-5.8.tar.gz ; cd ctags-5.8
	./configure --prefix=/usr
	make
	make install
	cd $cdir; rm -rf ctags-5.8

# QEMU
# ??? why ???, abud

	startStep qemu-0.14.1
	#http://download.savannah.gnu.org/releases/qemu/qemu-0.14.1.tar.gz
	tar -xzf qemu-0.14.1.tar.gz ; cd qemu-0.14.1
	./configure --prefix=/usr --disable-curl
	make qemu-img
	cp qemu-img /usr/bin/.
	cd $cdir; rm -rf qemu-0.14.1

# libxslt

	startStep libxslt-1.1.20
	tar -xzf libxslt-1.1.20.tar.gz; cd libxslt-1.1.20
	./configure --prefix=/usr --quiet
	make
	make install
	cd $cdir; rm -rf libxslt-1.1.20

# 6.37.1 (LFS 7.6) - bc-1.06.95

	startStep bc-1.06.95
	tar -xjf bc-1.06.95.tar.bz2; cd bc-1.06.95 
	patch -Np1 -i ../bc-1.06.95-memory_leak-1.patch
	# no need for info
	sed -i -e 's/all-am: Makefile \$(INFO_DEPS) \$(MANS)/all-am: Makefile \$(MANS)/' \
		-e 's/install-data-am: install-info-am install-man/install-data-am: install-man/' doc/Makefile.in
	./configure --prefix=/usr --with-readline --mandir=/usr/share/man 
	make
	make install
	cd $cdir; rm -rf bc-1.06.95

# Added dev
# Valgrind-3.18.1

	startStep valgrind-3.18.1
	tar -xf valgrind-3.18.1.tar.bz2; cd valgrind-3.18.1
	./configure --prefix=/usr
	make
	make install
	find /usr/libexec/valgrind -executable -name '*-linux' -exec strip --strip-all {} \;
	cd $cdir; rm -rf valgrind-3.18.1

# Man-pages-5.10

	startStep man-pages-5.10
	tar -xzf man-pages-5.10.tar.gz; cd man-pages-5.10
	make install
	cd $cdir; rm -rf man-pages-5.10

# docker files
# Removed
#
#	tar -xzf docker-18.06.1-ce.tgz
#	cd docker
#	cp * /usr/bin/
#	cd $cdir; rm -rf docker
#

# Added
# autoconf-2.69.tar.xz

	startStep autoconf-2.69
	tar -xf autoconf-2.69.tar.xz
	cd autoconf-2.69
	./configure --prefix=/usr
	make
	make install
	cd $cdir; rm -rf autoconf-2.69

# Added
# automake-1.15.tar.xz
	
	startStep automake-1.15
	tar -xf automake-1.15.tar.xz
	cd automake-1.15
	./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.15
	make
	make install
	cd $cdir; rm -rf automake-1.15

echo
echo "#########################################################################"
echo "########################    EXTRA PACKAGES     ##########################"
echo


# Added dev
# Squashfs-4.4

	cd $cdir
	startStep squashfs4.4.tar.gz
	tar -xzf squashfs4.4.tar.gz; cd squashfs4.4
	cd squashfs-tools
	mv Makefile Makefile.orig
	sed -e 's@INSTALL_DIR = /usr/local/bin@INSTALL_DIR = /bin@' \
	    -e 's@#XZ_SUPPORT = 1@XZ_SUPPORT = 1@' \
	    Makefile.orig > Makefile
	make
	make install
	cd $cdir; rm -rf squashfs4.4

# Added dev
# Cdrtools-3.01 (mkisofs)

	cd $cdir
	startStep cdrtools-3.01
	tar -xjf cdrtools-3.01.tar.bz2; cd cdrtools-3.01
	make INS_BASE=/usr DEFMANBASE=cdrtools STRIPFLAGS=-s
	make INS_BASE=/usr DEFMANBASE=cdrtools STRIPFLAGS=-s install
	mkdir -pv /usr/share/man/man1
	mv /usr/cdrtools/man/man1/* /usr/share/man/man1/
	mkdir -pv /usr/share/man/man8
	mv /usr/cdrtools/man/man8/* /usr/share/man/man8/
	rm -rf /usr/cdrtools
	cd $cdir; rm -rf cdrtools-3.01

# libcgi-1.0

	cd $cdir
	startStep libcgi-1.0
	tar -xzf libcgi-1.0.tar.gz; cd libcgi-1.0
	if [ "$SYSTEM_ARCH" = "x86_64" ]; then
		CFLAGS=-fPIC ./configure --prefix=/usr
		CFLAGS=-fPIC make
	else
		./configure --prefix=/usr
		make
	fi
	make install
	cd ..; rm -rf libcgi-1.0

# swig-1.3.25

	cd $cdir
	startStep swig-1.3.25
	tar -xzf swig-1.3.25.tar.gz; cd swig-1.3.25
	./configure --prefix=/usr
	make
	make install
	cd ..; rm -rf swig-1.3.25

# Nasm-2.08rc5

	cd $cdir
	startStep nasm-2.08rc5	
	tar -xzf nasm-2.08rc5.tar.gz; cd nasm-2.08rc5
	./configure --prefix=/usr
	make
	make install
	cd ..; rm -rf nasm-2.08rc5

# Gdb-7.0
# Upgraded to
# Gdb-7.8.2

	cd $cdir
	startStep gdb-7.8.2
	tar -xzf gdb-7.8.2.tar.gz; cd gdb-7.8.2
	./configure --prefix=/usr --with-system-readline
	make
	make install
	cd ..; rm -rf gdb-7.8.2

# Added
# Libelf-elfutils-0.165
# From https://sourceware.org/elfutils/ftp/0.165/elfutils-0.165.tar.bz2

	cd $cdir
	startStep elfutils-0.165
	tar -xf elfutils-0.165.tar.bz2
	cd elfutils-0.165
	./configure --prefix=/usr --disable-debuginfod
	make
	make -C libelf install
	install -vm644 config/libelf.pc /usr/lib/pkgconfig
	rm /usr/lib/libelf.a
	cd ..; rm -rf elfutils-0.165


# Added dev /opt
# Cmake-3.19.6

	cd $cdir
	startStep cmake-3.19.6

	PATH=$PATH:/opt/cmake3/bin
	LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/cmake3/lib
	export PATH LD_LIBRARY_PATH

	tar -xzf cmake-3.19.6.tar.gz; cd cmake-3.19.6
	./configure --prefix=/opt/cmake3  --mandir=/share/man --docdir=/share/doc/cmake-3.19.6
	make
	make install

	# Updating /etc/man_db.conf
	echo "MANDATORY_MANPATH                       /opt/cmake3/share/man" >> /etc/man_db.conf
	echo "MANDATORY_MANPATH                       /opt/cmake3/man" >> /etc/man_db.conf
	echo "MANDB_MAP		/opt/cmake3/share/man	/var/cache/man" >> /etc/man_db.conf
	echo "MANDB_MAP		/opt/cmake3/man	/var/cache/man" >> /etc/man_db.conf

	# Updating the /etc/profile
	( echo
          echo "#included by AbdLFS step cmake-3.19.6"
	  echo "export PATH=\$PATH:/opt/cmake3/bin"
	  echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/opt/cmake3/lib"
	) >> /etc/profile

	cd ..; rm -rf cmake-3.19.6

# Added dev /opt
# Python

	cd $cdir
	startStep Python-3.9.1

	PATH=$PATH:/opt/python3/bin
	LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/python3/lib
	export PATH LD_LIBRARY_PATH

	tar xzvf Python-3.9.1.tgz; cd Python-3.9.1
	./configure --prefix=/opt/python3
		# May should put Python and Perl in /opt.
		# So be clear it's not part of production release
	make
	make install

	# Links for usual #!/usr/bin/perl shebang, Abud
	ln -s /opt/python3/bin/python3 /usr/bin/python
	ln -s /opt/python3/bin/python3 /usr/bin/python3

	# Updating /etc/man_db.conf
	echo "MANDATORY_MANPATH                       /opt/python3/share/man" >> /etc/man_db.conf
	echo "MANDB_MAP		/opt/python3/share/man	/var/cache/man" >> /etc/man_db.conf

	# Updating the /etc/profile
	( echo
          echo "#included by AbdLFS step Python-3.9.1"
	  echo "export PATH=\$PATH:/opt/python3/bin"
	  echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/opt/python3/lib"
	) >> /etc/profile

	cd ..; rm -rf Python-3.9.1


	# note:
	# --enable-optimizations appears to not worth time and risk
	# -> PGO  is a very complex technic que may yield a 10% speed gain for certain codes.
	# -> LTO  is a GCC optiomization technic that may worth in the future. But not now.
	#
	# Python is not in the critical path of anything in the system... So...
	#
	# https://gcc.gnu.org/onlinedocs/gccint/LTO-Overview.html
	# https://en.wikipedia.org/wiki/Profile-guided_optimization
	#
	# Abud

# Added dev /opt
# Llvm-11.0.1

	cd $cdir
	startStep llvm-project-11.0.1

	# Don't know exactly why, but llvm build under x86_64 kernel aborted twice.
	# I think may be because of high memory usage. But not sure
	# And not up to reaseach now.
	#
	# llvm is not fundamental for a 64bits system, neither for 32bits under 64bits kernel
	#

	if [ "$SYSTEM_ARCH" = "x86_64" ]; then
		echo "Supressing build of llvm in system running under x86_64 kernel"
	else
		PATH=$PATH:/opt/llvm11/bin
		LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/llvm11/lib
		export PATH LD_LIBRARY_PATH

		tar -xJf llvm-project-11.0.1.src.tar.xz
		cd llvm-project-11.0.1.src
		mkdir build-llvm
		cd build-llvm/
		cmake -G 'Unix Makefiles' \
			-DLLVM_ENABLE_PROJECTS='clang;lld' \
			-DCMAKE_INSTALL_PREFIX=/opt/llvm11 \
			-DLLVM_TARGETS_TO_BUILD="WebAssembly;X86;ARM;Mips" \
			-DLLVM_BUILD_LLVM_DYLIB=on \
			-DLLVM_LINK_LLVM_DYLIB=on \
			-DCMAKE_BUILD_TYPE=Release \
			../llvm
		make
		make install
		cd ..

		# No use for static llvm library set (it's for llvm based tools development).
		rm -rf /opt/llvm11/lib/*.a
		(
			cd /opt/llvm11/bin
			mkdir -pv /AbdLFSRemoved
			tar -cJf /AbdLFSRemoved/llvm-extras.tar.xz \
				bugpoint llvm-tblgen \
				llvm-xray obj2yaml \
				llvm-exegesis dsymutil \
				c-index-test
			rm -f bugpoint llvm-tblgen llvm-xray obj2yaml llvm-exegesis dsymutil c-index-test
		)

		# Updating /etc/man_db.conf
		echo "MANDATORY_MANPATH                       /opt/llvm11/share/man" >> /etc/man_db.conf
		echo "MANDB_MAP		/opt/llvm11/share/man	/var/cache/man" >> /etc/man_db.conf

		# Updating the /etc/profile
		( echo
		  echo "#included by AbdLFS step llvm-project-11.0.1"
		  echo "export PATH=\$PATH:/opt/llvm11/bin"
		  echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/opt/llvm11/lib"
		) >> /etc/profile

		cd ..; rm -rf llvm-project-11.0.1.src
	fi

echo
echo "#########################################################################"
echo "########################    FINAL MINOR ADJUST ##########################"
echo

#####################
# /opt/extras
#

	echo "MANDATORY_MANPATH		/opt/extras/share/man" >> /etc/man_db.conf
	echo "MANDB_MAP			/opt/extras/share/man	/var/cache/man" >> /etc/man_db.conf


# SSHD-PermitRootLogin

	startStep SSHD-PermitRootLogin
	# Enable root login via ssh
	sed -i '1,$s/#PermitRootLogin.*prohibit-password/PermitRootLogin yes/'   /etc/ssh/sshd_config


echo; echo "AbdLFS: $(date +%Y%m%d-%H%M%S) - Finished $LFSSCRIPTNAME"; echo
