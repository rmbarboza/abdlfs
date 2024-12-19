#!/bin/sh

#Main system creation script

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

check_system()
{
	find / -type f -print |
	egrep -v -e '^/sources|^/extensions|^sources_dev|^/tools|^/dev|^/proc|^/sys' |
	while read fname; do cksum $fname; done
}

MKTEST=NO
LOGS=/installlogs
KARCH=`uname -m`

cd /sources
mkdir ${LOGS}

echo
echo "########################    LFS-9              ##########################"
echo

# 6.7. Linux-2.6.30.2 API Headers
# Upgraded to
# 6.7. Linux-3.10.104 API Headers
# Upgraded to
# 6.7. Linux-3.16.61 API Headers

	startStep 6.7-"$KERNEL_VERSION"-api-headers
	tar -xJf "$KERNEL_VERSION".tar.xz; cd "$KERNEL_VERSION"
	make mrproper
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make headers_check &> ${LOGS}/check-${LFSSTEP}.log
	fi
	make INSTALL_HDR_PATH=dest headers_install
	cp -rv dest/include/* /usr/include
	cd /sources; rm -rf "$KERNEL_VERSION"

# 6.8 manpages skiped - Abud

	# Abud - no docs

# 6.9. Glibc-2.10.1
# Upgraded to
# 6.9. Glibc-2.20 (test)
# Upgraded to 
# 6.9. Glibc-2.22 (test)
# Upgraded to 
# 6.9. Glibc-2.23 

	startStep 6.9-glibc-2.23

	tar -xzf glibc-2.23.tar.gz
	cd glibc-2.23

	gunzip -c ../glibc-2.23-fhs-1.patch.gz > ../glibc-2.23-fhs-1.patch
	patch -Np1 -i ../glibc-2.23-fhs-1.patch
	rm -f ../glibc-2.23-fhs-1.patch

#	gunzip -c ../glibc-2.22-upstream_i386_fix-1.patch.gz > ../glibc-2.22-upstream_i386_fix-1.patch
#	patch -Np1 -i ../glibc-2.22-upstream_i386_fix-1.patch
#	rm -f ../glibc-2.22-upstream_i386_fix-1.patch

	mkdir -v ../glibc-build
	cd ../glibc-build

	../glibc-2.23/configure    \
	    --prefix=/usr          \
	    --disable-profile      \
	    --enable-kernel=2.6.32 \
	    --enable-obsolete-rpc

	make
	
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check 2>&1 | tee ${LOGS}/glibc-check-log
		grep Error ${LOGS}/glibc-check-log > ${LOGS}/check-${LFSSTEP}.Error.log
		grep FAIL: ${LOGS}/glibc-check-log > ${LOGS}/check-${LFSSTEP}.Fail.log
		# Abud - needs visual check
	fi

	touch /etc/ld.so.conf

	make install

	cp -v ../glibc-2.23/nscd/nscd.conf /etc/nscd.conf
	mkdir -pv /var/cache/nscd

	echo "Removing unneeded locales, keeping only en_US"
	ls /usr/share/i18n/locales/* |
	grep -v -e 'en_US' -e 'en_GB' -e 'POSIX' -e 'iso14651' -e 'locales/i18n$' -e 'translit_' |
	while read x
	do
		rm -fv $x
	done

	rm -v /usr/share/i18n/locales/translit_hangul
	rm -v /usr/share/i18n/locales/translit_cjk_variants
	rm -v /usr/share/i18n/locales/iso14651_t1_pinyin

	mkdir -pv /usr/lib/locale
	localedef -i en_US -f ISO-8859-1 en_US
	localedef -i en_US -f UTF-8 en_US.UTF-8

##	# to install all locales use:
##	# make localedata/install-locales
##
	cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
#End /etc/nsswitch.conf
EOF

	# Abud - needs interaction
	# tzelect

	# Fixme (2.0.0): Abud, Sao_Paulo missing file !!! ???? !!!!
	# Sao Paulo default
	#	cp -v --remove-destination /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/lib
/usr/local/lib
/opt/lib
/opt/extras/lib
# End /etc/ld.so.conf
EOF

        cd ..; rm -rf glibc-2.23; rm -rf glibc-build

# 6.10. Re-adjusting the Toolchain

	startStep 6.10-re-adjusting

	mv -v /tools/bin/{ld,ld-old}
	mv -v /tools/$(gcc -dumpmachine)/bin/{ld,ld-old}
	mv -v /tools/bin/{ld-new,ld}
	ln -sv /tools/bin/ld /tools/$(gcc -dumpmachine)/bin/ld

	gcc -dumpspecs | sed -e 's@'$LFS'/tools@@g' \
		-e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
		-e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' > \
		`dirname $(gcc --print-libgcc-file-name)`/specs

	# Abud - needs visual check
	
	(
		echo 'main(){}' > dummy.c
		cc dummy.c -v -Wl,--verbose &> dummy.log
		readelf -l a.out | grep ': /lib'

		# should show: /lib/ld-linux.so.2

		grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log

		#should show
		#
		#	/usr/lib/crt1.o succeeded
		#	/usr/lib/crti.o succeeded
		#	/usr/lib/crtn.o succeeded
		#

		grep -B1 '^ /usr/include' dummy.log

		# should show
		#	#include <...> search starts here:
		#	/usr/include

		grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'

		# output
		#	SEARCH_DIR("/tools/i686-pc-linux-gnu/lib")
		#	SEARCH_DIR("/usr/lib")
		#	SEARCH_DIR("/lib");
	
		grep "/lib.*/libc.so.6 " dummy.log

		# outout
		#
		#	attempt to open /lib/libc.so.6 succeeded
	
		grep found dummy.log

		# output
		#
		#	found ld-linux.so.2 at /lib/ld-linux.so.2
	
		rm -v dummy.c a.out dummy.log
	) &> ${LOGS}/check-${LFSSTEP}.log


# 6.11. Zlib-1.2.3

	startStep 6.11-zlib-1.2.3
	tar -xjf zlib-1.2.3.tar.bz2 ; cd zlib-1.2.3

	./configure --prefix=/usr --shared --libdir=/lib

	make
	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}-1.log
	fi

	make install

	rm -v /lib/libz.so
	ln -sfv ../../lib/libz.so.1.2.3 /usr/lib/libz.so

	make clean
	./configure --prefix=/usr

	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}-2.log
	fi

	make install

	chmod -v 644 /usr/lib/libz.a

	cd /sources; rm -rf zlib-1.2.3

# 6.12. Binutils-2.19.1
# Upgraded to
# 6.12. Binutils-2.24

	startStep 6.12-binutils-2.24
	tar -xjf binutils-2.24.tar.bz2; cd binutils-2.24

	# Abud - needs visual check 
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		expect -c "spawn ls" &> ${LOGS}/check-${LFSSTEP}-1.log

		# output;
		#	spawn ls

		# should not include:
		# 	The system has no more ptys.
		#	Ask your system administrator to create more.
	fi

	mkdir -v ../binutils-build
	cd ../binutils-build
	
	../binutils-2.24/configure --prefix=/usr  --enable-shared --disable-werror

	make tooldir=/usr

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}-2.log
	fi

	make tooldir=/usr install

	cd /sources; rm -rf binutils-2.24; rm -rf binutils-build
	

# 6.13. GMP-4.3.1
# Upgraded to
# 6.13. GMP-6.0.0a

	startStep 6.13-GMP-6.0.0a
	tar -xjf gmp-6.0.0a.tar.bz2; cd gmp-6.0.0

	./configure --prefix=/usr --enable-cxx --docdir=/usr/share/doc/gmp-6.0.0a
	make
	
	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check 2>&1 | tee gmp-check-log
		awk '/tests passed/{total+=$2} ; END{print total}' gmp-check-log &> ${LOGS}/check-${LFSSTEP}.log
		# output
		#	143
	fi

	make install
	
	# Abud - no docs
	# mkdir -v /usr/share/doc/gmp-4.3.1
	# cp -v doc/{isa_abi_headache,configuration} doc/*.html  /usr/share/doc/gmp-4.3.1

	cd /sources; rm -rf gmp-6.0.0

# 6.14. MPFR-2.4.1
# Upgraded to
# 6.14. MPFR-3.1.2
# Upgraded to
# 6.14. MPFR-3.1.3

	startStep 6.14-MPFR-3.1.3
	tar -xjf mpfr-3.1.3.tar.bz2; cd mpfr-3.1.3

	gunzip -c ../mpfr-3.1.3-upstream_fixes-1.patch.gz > ../mpfr-3.1.3-upstream_fixes-1.patch
	patch -Np1 -i ../mpfr-3.1.3-upstream_fixes-1.patch
	rm -f ../mpfr-3.1.3-upstream_fixes-1.patch
 
	./configure --prefix=/usr --enable-thread-safe --docdir=/usr/share/doc/mpfr-3.1.3
	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}.log

		# output
		#
		#	All 148 tests passed
	fi

	make install

	# Abud - no docs
	# make html
	# mkdir -pv /usr/share/doc/mpfr-2.4.1
	# find . -name \*.html -type f -exec cp -v \{} /usr/share/doc/mpfr-2.4.1 \;

	cd /sources; rm -rf mpfr-3.1.3

# 6.14b MPC-1.0.2
# Upgraded to
# 6.14b MPC-1.0.3

	startStep 6.14b-MPC-1.0.3
	tar -xzf mpc-1.0.3.tar.gz; cd mpc-1.0.3

	./configure --prefix=/usr --docdir=/usr/share/doc/mpc-1.0.3

	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}.log

		# output
		#
		#	All 148 tests passed
	fi


	make install
	cd /sources; rm -rf mpc-1.0.3

# 6.15. GCC-4.4.1
# Upgraded to
# 6.15. GCC-4.9.1 - pass 2 (just for test)
# Upgraded to
# 6.15. GCC-5.2.0

	startStep 6.15-gcc-5.2.0
	check_system > ${LOGS}/cksum.gcc.before.txt

	tar -xjf gcc-5.2.0.tar.bz2; cd gcc-5.2.0

#	sed -i 's/install_to_$(INSTALL_DEST) //' libiberty/Makefile.in
#
#	case `uname -m` in
#		i?86) sed -i 's/^T_CFLAGS =$/& -fomit-frame-pointer/' gcc/Makefile.in ;;
#	esac
#
#	sed -i 's@\./fixinc\.sh@-c true@' gcc/Makefile.in

	mkdir -v ../gcc-build
	cd ../gcc-build

	../gcc-5.2.0/configure --prefix=/usr \
		--enable-shared \
		--enable-clocale=gnu \
		--enable-languages=c,c++ \
		--disable-multilib --disable-bootstrap \
		--with-system-zlib

	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		#make -k check
		# Do not stop at erros
		ulimit -s 32768
		make -k check || true
		../gcc-4.4.1/contrib/test_summary > ${LOGS}/check-${LFSSTEP}-test_summary.log
		grep -A 7 'Summ' ${LOGS}/check-${LFSSTEP}-test_summary.log &> ${LOGS}/check-${LFSSTEP}-1.log
	fi
	
	make install-strip

	ln -sv ../usr/bin/cpp /lib
	ln -sv gcc /usr/bin/cc

	install -v -dm755 /usr/lib/bfd-plugins
	ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/5.2.0/liblto_plugin.so /usr/lib/bfd-plugins/

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		(
		echo 'main(){}' > dummy.c
		cc dummy.c -v -Wl,--verbose &> dummy.log
		readelf -l a.out | grep ': /lib'

		# output
		#
		#	[Requesting program interpreter: /lib/ld-linux.so.2]

		grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log

		# output
		#
		#	/usr/lib/gcc/i686-pc-linux-gnu/4.4.1/../../../crt1.o succeeded
		#	/usr/lib/gcc/i686-pc-linux-gnu/4.4.1/../../../crti.o succeeded
		#	/usr/lib/gcc/i686-pc-linux-gnu/4.4.1/../../../crtn.o succeeded

		grep -B4 '^ /usr/include' dummy.log

		# output
		#	#include <...> search starts here:
		#	/usr/local/include
		#	/usr/lib/gcc/x86_64-unknown-linux-gnu/4.4.1/include
		#	/usr/lib/gcc/i686-pc-linux-gnu/4.4.1/include-fixed
		#	/usr/include

		grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'

		# output
		#	SEARCH_DIR("/usr/i686-pc-linux-gnu/lib")
		#	SEARCH_DIR("/usr/local/lib")
		#	SEARCH_DIR("/lib")
		#	SEARCH_DIR("/usr/lib");
		#
		# output 64 bits
		#	SEARCH_DIR("/usr/x86_64-unknown-linux-gnu/lib64")
		#	SEARCH_DIR("/usr/local/lib64")
		#	SEARCH_DIR("/lib64")
		#	SEARCH_DIR("/usr/lib64")
		#	SEARCH_DIR("/usr/x86_64-unknown-linux-gnu/lib")
		#	SEARCH_DIR("/usr/local/lib")
		#	SEARCH_DIR("/lib")
		#	SEARCH_DIR("/usr/lib");

		grep "/lib.*/libc.so.6 " dummy.log

		# output
		#	attempt to open /lib/libc.so.6 succeeded

		grep found dummy.log

		# output
		#	found ld-linux.so.2 at /lib/ld-linux.so.2

		rm -v dummy.c a.out dummy.log
		) &> ${LOGS}/check-${LFSSTEP}-2.log
	fi

	mkdir -pv /usr/share/gdb/auto-load/usr/lib
	mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib

	cd /sources; rm -rf gcc-5.2.0; rm -rf gcc-build

	check_system > ${LOGS}/cksum.gcc.after.txt

# 6.16. Sed-4.2.1

	startStep 6.16-sed-4.2.1
	tar -xjf sed-4.2.1.tar.bz2 ; cd sed-4.2.1

	./configure --prefix=/usr --bindir=/bin --htmldir=/usr/share/doc/sed-4.2.1

	make

	# Abud - no docs
	# make html

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}.log

		# output
		#
		#	All 65 tests behaved as expected (4 expected failures)
	fi

	make install

	# Abud - no docs
	# make -C doc install-html

	cd /sources; rm -rf sed-4.2.1

# 6.17. Pkg-config-0.23
# Upgraded to
# 6.17. Pkg-config-0.28

	startStep 6.17-pkg-config-0.28
	tar -xzf pkg-config-0.28.tar.gz; cd pkg-config-0.28

	CFLAGS="-Wno-unused-local-typedefs" ./configure \
		--prefix=/usr \
		--with-internal-glib \
		--with-pc-path=/usr/lib/pkgconfig:/usr/share/pkgconfig:/opt/extras/lib/pkgconfig:/opt/extras/share/pkgconfig \
		--disable-host-tool  \
		--docdir=/usr/share/doc/pkg-config-0.28
	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}.log
		#output
		#
		#	All 6 tests passed
	fi

	make install

	cd /sources; rm -rf pkg-config-0.28

# Added
# 6.23.1. libcap-2.25.tar.xz

	startStep libcap-2.25
	tar -xf libcap-2.25.tar.xz; cd libcap-2.25
	make
	make RAISE_SETFCAP=no prefix=/usr install
	mv -v /usr/lib/libcap.so.* /lib
	ln -sfv ../../lib/$(readlink /usr/lib/libcap.so) /usr/lib/libcap.so
	cd /sources; rm -rf libcap-2.25


# 6.18. Ncurses-5.7

	startStep 6.18-ncurses-5.7
	tar -xzf ncurses-5.7.tar.gz; cd ncurses-5.7

	./configure --prefix=/usr --with-shared --without-debug --enable-widec \
		    --mandir=/usr/share/man

	make
	make install
	mv -v /usr/lib/libncursesw.so.5* /lib
	ln -sfv ../../lib/libncursesw.so.5 /usr/lib/libncursesw.so

	for lib in ncurses form panel menu ; do \
		rm -vf /usr/lib/lib${lib}.so ; \
		echo "INPUT(-l${lib}w)" >/usr/lib/lib${lib}.so ; \
		ln -sfv lib${lib}w.a /usr/lib/lib${lib}.a ; \
	done

	ln -sfv libncurses++w.a /usr/lib/libncurses++.a

	rm -vf /usr/lib/libcursesw.so
	echo "INPUT(-lncursesw)" >/usr/lib/libcursesw.so
	ln -sfv libncurses.so /usr/lib/libcurses.so
	ln -sfv libncursesw.a /usr/lib/libcursesw.a
	ln -sfv libncurses.a /usr/lib/libcurses.a

	# Abud - no docs
	# mkdir -v /usr/share/doc/ncurses-5.7
	# cp -v -R doc/* /usr/share/doc/ncurses-5.7

	# Abud - removed 
	# make distclean
	# ./configure --prefix=/usr --with-shared --without-normal  --without-debug --without-cxx-binding
	# make sources libs
	# cp -av lib/lib*.so.5* /usr/lib

	cd /sources; rm -rf ncurses-5.7

# 6.19. Util-linux-ng-2.16

	startStep 6.19-util-linux-ng-2.16
	tar -xjf util-linux-ng-2.16.tar.bz2; cd util-linux-ng-2.16

	sed -e 's@etc/adjtime@var/lib/hwclock/adjtime@g'  -i $(grep -rl '/etc/adjtime' .)
	mkdir -pv /var/lib/hwclock

	./configure --enable-arch --enable-partx --enable-write

	make
	make install

	cd /sources; rm -rf util-linux-ng-2.16


# 6.20. E2fsprogs-1.41.8
# Upgraded 
# 6.20. E2fsprogs-1.42.13

	startStep 6.20-e2fsprogs-1.42.13
	tar -xzf e2fsprogs-1.42.13.tar.gz; cd e2fsprogs-1.42.13

	sed -e '/int.*old_desc_blocks/s/int/blk64_t/' \
	    -e '/if (old_desc_blocks/s/super->s_first_meta_bg/desc_blocks/' \
	    -i lib/ext2fs/closefs.c

	mkdir -v build
	cd build

	LIBS=-L/tools/lib                    \
	CFLAGS=-I/tools/include              \
	../configure --prefix=/usr --bindir=/bin --with-root-prefix="" \
		--enable-elf-shlibs --disable-libblkid --disable-libuuid \
		--disable-uuidd --disable-fsck

	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		# fixme
		true
		###make check &> ${LOGS}/check-${LFSSTEP}.log
		# output
		#  102 tests succeeded     0 tests failed
	fi

	make install
	make install-libs

	chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a

	# Abud - no docs

	#gunzip -v /usr/share/info/libext2fs.info.gz
	#install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

	#makeinfo -o doc/com_err.info ../lib/et/com_err.texinfo
	#install -v -m644 doc/com_err.info /usr/share/info
	#install-info --dir-file=/usr/share/info/dir  /usr/share/info/com_err.info

	cd /sources; rm -rf e2fsprogs-1.42.13

# 6.21. Coreutils-7.4

	startStep 6.21-coreutils-7.4
	tar -xzf coreutils-7.4.tar.gz; cd coreutils-7.4
	
	case `uname -m` in
		i?86 | x86_64) patch -Np1 -i ../coreutils-7.4-uname-1.patch ;;
	esac

	patch -Np1 -i ../coreutils-7.4-i18n-1.patch

	./configure --prefix=/usr  --enable-no-install-program=kill,uptime

	make

	# Abud - Fixme
	#	make NON_ROOT_USERNAME=nobody check-root
	#	echo "dummy:x:1000:nobody" >> /etc/group
	#	chown -Rv nobody config.log {gnulib-tests,lib,src}/.deps

	#	su-tools nobody -s /bin/bash -c "make RUN_EXPENSIVE_TESTS=yes check" || true
	#	sed -i '/dummy/d' /etc/group

	make install

	mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
	mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
	mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin
	mv -v /usr/bin/chroot /usr/sbin

	mv -v /usr/bin/{head,sleep,nice} /bin

	# Abud (for use with usr squashed system)
	cp -f /usr/bin/env /bin

	cd /sources; rm -rf coreutils-7.4

# 6.22. Iana-Etc-2.30

	startStep 6.22-iana-etc-2.30
	tar -xjf iana-etc-2.30.tar.bz2; cd iana-etc-2.30
	make
	make install
	cd /sources; rm -rf iana-etc-2.30

# 6.23. M4-1.4.13

	startStep 6.23-m4-1.4.13
	tar -xjf m4-1.4.13.tar.bz2; cd m4-1.4.13
	./configure --prefix=/usr
	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}.log
		# output
		# All 76 tests passed
		# (1 test was not run)
	fi
	
	make install
	cd /sources; rm -rf m4-1.4.13

# 6.24. Bison-2.4.1

	startStep 6.24-bison-2.4.1
	tar -xjf bison-2.4.1.tar.bz2; cd bison-2.4.1
	./configure --prefix=/usr
	echo '#define YYENABLE_NLS 1' >> config.h
	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}.log
		# output
		#   224 tests were successful.
		#   16 tests were skipped.
	fi

	make install

	cd /sources; rm -rf bison-2.4.1

# 6.25. Procps-3.2.8
# Upgraded to
# 6.25. Procps-ng-3.3.1

	startStep 6.25-procps-ng-3.3.1
	tar -xzvf procps-ng-3.3.1.tar.gz; cd procps-ng-3.3.1
	./configure --prefix=/usr   \
	    --sysconfdir=/etc \
	    --sbindir=/sbin \
	    --exec-prefix= \
	    --libdir=/usr/lib \
	    --docdir=/usr/share/doc/procps-ng-3.3.11 \
	    --disable-static \
	    --disable-kill
	make
	make install
	cd /sources; rm -rf procps-ng-3.3.1

# ################### stoped here
# 6.26. Grep-2.5.4

	startStep 6.26-grep-2.5.4
	tar -xjf grep-2.5.4.tar.bz2 ; cd grep-2.5.4

	patch -Np1 -i ../grep-2.5.4-debian_fixes-1.patch
	./configure --prefix=/usr --bindir=/bin --without-included-regex

	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		(make check || true) &> ${LOGS}/check-${LFSSTEP}.log
		# output
		# 1 of 14 tests failed
		# Abud - expected failure of fmbtest.sh

		# output
		# There are known test failures in the fmbtest.sh tests. The "|| true" construct
		# is used to avoid automated build scripts
		# failing due to the test failures. A good run will show 1 failure from 14 tests,
		# although the test failure will detail 2 failed sub-tests.
	fi

	make install

	cd /sources; rm -rf grep-2.5.4

# 6.27. Readline-6.0

	startStep 6.27-readline-6.0
	tar -xzf readline-6.0.tar.gz ; cd readline-6.0

	sed -i '/MV.*old/d' Makefile.in
	sed -i '/{OLDSUFF}/c:' support/shlib-install
	patch -Np1 -i ../readline-6.0-fixes-1.patch

	./configure --prefix=/usr --libdir=/lib

	make SHLIB_LIBS=-lncurses
	make install

	mv -v /lib/lib{readline,history}.a /usr/lib

	rm -v /lib/lib{readline,history}.so
	ln -sfv ../../lib/libreadline.so.6 /usr/lib/libreadline.so
	ln -sfv ../../lib/libhistory.so.6 /usr/lib/libhistory.so

	# Abud - no docs
	# mkdir -v /usr/share/doc/readline-6.0
	# install -v -m644 doc/*.{ps,pdf,html,dvi}  /usr/share/doc/readline-6.0

	cd /sources; rm -rf readline-6.0

# 6.28. Bash-4.0
# Upgraded to
# 6.28. Bash-4.4.18

	startStep 6.28-bash-4.4.18
	tar -xzf bash-4.4.18.tar.gz ; cd bash-4.4.18

#	patch -Np1 -i ../bash-4.0-fixes-3.patch

	./configure --prefix=/usr --bindir=/bin \
		--htmldir=/usr/share/doc/bash-4.4.18 --without-bash-malloc

	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		# fixme
		true
		# fixme
		# sed -i 's/LANG/LC_ALL/' tests/intl.tests
		# sed -i 's@tests@& </dev/tty@' tests/run-test
		# chown -Rv nobody ./
		# su-tools nobody -s /bin/bash -c "make tests"
	fi

	make install

	# fixme - need to start new script here.
	# exec /bin/bash --login +h

	cd /sources; rm -rf bash-4.4.18

# 6.29. Libtool-2.2.6a

	startStep 6.29-libtool-2.2.6a
	tar -xzf libtool-2.2.6a.tar.gz; cd libtool-2.2.6
	./configure --prefix=/usr
	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}.log
		# output
		# ???? Abud
		# (1 tests were not run)
		# 69 tests behaved as expected.
		# 5 tests were skipped.
	fi

	make install
	cd /sources; rm -rf libtool-2.2.6


###########################

# 6.30. GDBM-1.8.3

	startStep 6.30-gdbm-1.8.3
	tar -xzf gdbm-1.8.3.tar.gz; cd gdbm-1.8.3
	./configure --prefix=/usr
	make
	make install
	make install-compat
	cd /sources; rm -rf gdbm-1.8.3

# 6.31. Inetutils-1.6

	startStep 6.31-inetutils-1.6
	tar -xzf inetutils-1.6.tar.gz ; cd inetutils-1.6

	patch -Np1 -i ../inetutils-1.6-no_server_man_pages-1.patch

	./configure --prefix=/usr --libexecdir=/usr/sbin \
		--localstatedir=/var --disable-ifconfig \
		--disable-logger --disable-syslogd --disable-whois \
		--disable-servers

	make

	make install

	mv -v /usr/bin/ping /bin

	cd /sources; rm -rf inetutils-1.6

# 6.32. Perl-5.10.0

	#	echo "127.0.0.1 localhost $(hostname)" > /etc/hosts
	#
	#	patch -Np1 -i ../perl-5.10.0-consolidated-1.patch
	#	
	#	sed -i -e "s|BUILD_ZLIB\s*= True|BUILD_ZLIB = False|" \
	#	-e "s|INCLUDE\s*= ./zlib-src|INCLUDE = /usr/include|" \
	#	-e "s|LIB\s*= ./zlib-src|LIB = /usr/lib|" \
	#	ext/Compress/Raw/Zlib/config.in

	#	sh Configure -des -Dprefix=/usr \
	#		-Dvendorprefix=/usr \
	#		-Dman1dir=/usr/share/man/man1 \
	#		-Dman3dir=/usr/share/man/man3 \
	#		-Dpager="/usr/bin/less -isR"

	#	make
	#
	#	make test
	#
	#	make install

# 6.33. Autoconf-2.64

	#	./configure --prefix=/usr
	#
	#	make
	#
	#	make check
	#	make install

# 6.34. Automake-1.11

	#	./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.11
	#	make
	#	make check
	#	make install

# 6.35. Bzip2-1.0.5

	startStep 6.35-bzip2-1.0.5
	tar -xzf bzip2-1.0.5.tar.gz ; cd bzip2-1.0.5

	patch -Np1 -i ../bzip2-1.0.5-install_docs-1.patch
	sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile

	make -f Makefile-libbz2_so
	make clean
	make
	make PREFIX=/usr install

	cp -v bzip2-shared /bin/bzip2
	cp -av libbz2.so* /lib
	ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
	rm -v /usr/bin/{bunzip2,bzcat,bzip2}
	ln -sv bzip2 /bin/bunzip2
	ln -sv bzip2 /bin/bzcat

	cd /sources; rm -rf bzip2-1.0.5

# 6.36. Diffutils-2.8.1
	
	startStep 6.36-diffutils-2.8.1
	tar -xzf diffutils-2.8.1.tar.gz ; cd diffutils-2.8.1

	patch -Np1 -i ../diffutils-2.8.1-i18n-1.patch

	touch man/diff.1

	./configure --prefix=/usr
	make
	make install

	cd /sources; rm -rf diffutils-2.8.1

# 6.37. File-5.03

	startStep 6.37-file-5.03
	tar -xzf file-5.03.tar.gz ; cd file-5.03

	./configure --prefix=/usr
	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}.log
		# output
		#
	fi

	make install

	cd /sources; rm -rf file-5.03

# 6.38. Gawk-3.1.7

	startStep 6.38-gawk-3.1.7
	tar -xjf gawk-3.1.7.tar.bz2 ; cd gawk-3.1.7

	./configure --prefix=/usr --libexecdir=/usr/lib
	make
	
	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}.log
		# output
		#
		#	ALL TESTS PASSED
	fi

	make install

	# Abud - no docs
	#	mkdir -v /usr/share/doc/gawk-3.1.7
	#	cp -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-3.1.7

	cd /sources; rm -rf gawk-3.1.7

# 6.39. Findutils-4.4.2

	startStep 6.39-findutils-4.4.2
	tar -xzf findutils-4.4.2.tar.gz ; cd findutils-4.4.2
	
	./configure --prefix=/usr --libexecdir=/usr/lib/findutils  --localstatedir=/var/lib/locate
	make

	# Abud - needs visual checl
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}.log
		# output 
		#
		#	needs to work (hint expected...)
	fi

	make install

	mv -v /usr/bin/find /bin
	sed -i 's/find:=${BINDIR}/find:=\/bin/' /usr/bin/updatedb

	cd /sources; rm -rf findutils-4.4.2

# 6.40. Flex-2.5.35

	startStep 6.40-flex-2.5.35
	tar -xjf flex-2.5.35.tar.bz2 ; cd flex-2.5.35

	patch -Np1 -i ../flex-2.5.35-gcc44-1.patch
	./configure --prefix=/usr
	make
	
	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}.log
		# output
		#
		#	Tests succeeded: 46
		#	Tests FAILED: 0
	fi

	make install

	ln -sv libfl.a /usr/lib/libl.a

	cat > /usr/bin/lex << "EOF"
#!/bin/sh
# Begin /usr/bin/lex
exec /usr/bin/flex -l "$@"
# End /usr/bin/lex
EOF
	chmod -v 755 /usr/bin/lex

	# Abud - no docs
	# mkdir -v /usr/share/doc/flex-2.5.35
	# cp -v doc/flex.pdf /usr/share/doc/flex-2.5.35

	cd /sources; rm -rf flex-2.5.35

# 6.41. Gettext-0.17

	# Abud - let's try without gettext
	#
	#	patch -Np1 -i ../gettext-0.17-upstream_fixes-2.patch
	#	./configure --prefix=/usr --docdir=/usr/share/doc/gettext-0.17
	#
	#	make
	#	make check
	#	make install

# 6.42. Groff-1.20.1

	# Abud - let's try without groff
	#
	#	PAGE=A4 ./configure --prefix=/usr
	#
	#	make
	#	make docdir=/usr/share/doc/groff-1.20.1 install
	#	ln -sv eqn /usr/bin/geqn
	#	ln -sv tbl /usr/bin/gtbl

# 6.43. Gzip-1.3.12
# Upgraded to
# 6.43. Gzip-1.6

	startStep 6.43-gzip-1.6
	tar -xzf gzip-1.6.tar.gz ; cd gzip-1.6

	./configure --prefix=/usr --bindir=/bin
	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}.log
		# output
		#
		#	Test succeeded.
	fi

	make install

	mv -v /bin/{gzexe,uncompress,zcmp,zdiff,zegrep} /usr/bin
	mv -v /bin/{zfgrep,zforce,zgrep,zless,zmore,znew} /usr/bin

	cd /sources; rm -rf gzip-1.6

# 6.44. IPRoute2-2.6.29-1
# Upgraded to
# 6.44. IPRoute2-3.16.0

	startStep 6.44-iproute2-3.16.0
	tar -xzf iproute2-3.16.0.tar.gz ; cd iproute2-3.16.0

	sed -i '/^TARGETS/s@arpd@@g' misc/Makefile
	sed -i /ARPD/d Makefile
	sed -i 's/arpd.8//' man/man8/Makefile

	make

	# Abud - warning - more to do here - read PDF

	make DOCDIR=/usr/share/doc/iproute2-2.6.29-1 install

	cd /sources; rm -rf iproute2-3.16.0

# 6.45. Kbd-1.15

	startStep 6.45-kdb-1.15
	tar -xzf kbd-1.15.tar.gz ; cd kbd-1.15

	patch -Np1 -i ../kbd-1.15-backspace-1.patch

	./configure --prefix=/usr --datadir=/lib/kbd
	make
	make install
	
	mv -v /usr/bin/{kbd_mode,loadkeys,openvt,setfont} /bin

	# Abud - no docs
	#	mkdir -v /usr/share/doc/kbd-1.15
	#	cp -R -v doc/*  /usr/share/doc/kbd-1.15

	cd /sources; rm -rf kbd-1.15

# 6.46. Less-429

	startStep 6.46-less-429
	tar -xzf less-429.tar.gz ; cd less-429

	./configure --prefix=/usr --sysconfdir=/etc
	make
	make install

	cd /sources; rm -rf less-429

# 6.47. Make-3.81
# Upgraded to
# 6.47. Make-4.0

	startStep 6.47-make-4.0
	tar -xzf make-4.0.tar.gz ; cd make-4.0

	./configure --prefix=/usr
	make

	# Abud - needs visual checl
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSFACE}.log
		#
		#	351 Tests in 96 Categories Complete ... No Failures :-)
		#
	fi

	make install

	cd /sources; rm -rf make-4.0

# 6.48. Man-DB-2.5.5

#	startStep Man-DB-2.5.5
#	tar -xzf man-db-2.5.5.tar.gz ; cd man-db-2.5.5
#
#	patch -Np1 -i ../man-db-2.5.5-fix_testsuite-1.patch
#
#	./configure --prefix=/usr --libexecdir=/usr/lib \
#		--sysconfdir=/etc --disable-setuid \
#		--with-browser=/usr/bin/lynx --with-vgrind=/usr/bin/vgrind \
#		--with-grap=/usr/bin/grap
#	
#		make
#
#	if [ DD${MKTEST}DD = DDYESDD ]
#	then
#		make check
#	fi
#
#	make install
#
#	cd /sources; rm -rf man-db-2.5.5

# 6.49. Module-Init-Tools-3.10
# Upgraded to
# 6.49. Module-Init-Tools-3.12

	startStep 6.49-module-init-tools-3.12
	tar -xjf module-init-tools-3.12.tar.bz2 ; cd module-init-tools-3.12


	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		# fixme
		./configure
		true
		make check
		./tests/runtests
		#
		#	????
		#
		make clean
	fi

	DOCBOOKTOMAN=/bin/true ./configure --prefix=/ --enable-zlib --mandir=/usr/share/man
	make
	make INSTALL=install install

	cd /sources; rm -rf module-init-tools-3.12


# 6.50. Patch-2.5.9

	startStep 6.50-patch-2.5.9
	tar -xzf patch-2.5.9.tar.gz ; cd patch-2.5.9

	patch -Np1 -i ../patch-2.5.9-fixes-1.patch
	./configure --prefix=/usr
	make
	make install

	cd /sources; rm -rf patch-2.5.9

# 6.51. Psmisc-22.8
	
	startStep 6.51-psmisc-22.8
	tar -xzf psmisc-22.8.tar.gz ; cd psmisc-22.8

	./configure --prefix=/usr --exec-prefix=""
	make
	make install

	mv -v /bin/pstree* /usr/bin

	ln -sv killall /bin/pidof
	
	cd /sources; rm -rf psmisc-22.8

# 6.52. Shadow-4.1.4.2

	startStep 6.52-shadow-4.1.4.2
	tar -xjf shadow-4.1.4.2.tar.bz2 ;  cd shadow-4.1.4.2

	sed -i 's/groups$(EXEEXT) //' src/Makefile.in
	find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \;
	sed -i -e 's/ ko//' -e 's/ zh_CN zh_TW//' man/Makefile.in

	sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD MD5@' -e 's@/var/spool/mail@/var/mail@' etc/login.defs
	sed -i 's@DICTPATH.*@DICTPATH\t/lib/cracklib/pw_dict@' etc/login.defs

	sed -i '1,$s/MAIL_CHECK_ENAB.*yes/MAIL_CHECK_ENAB no/' etc/login.defs
	#sed -i '1,$s/FAILLOG_ENAB.*yes/FAILLOG_ENAB no/'       etc/login.defs
	#sed -i '1,$s/LASTLOG_ENAB.*yes/LASTLOG_ENAB no/'       etc/login.defs

	./configure --sysconfdir=/etc
	make
	make install

	mv -v /usr/bin/passwd /bin

	pwconv
	grpconv

	cd /sources; rm -rf shadow-4.1.4.2

# 6.53. Sysklogd-1.5

	startStep 6.53-sysklogd-1.5
	tar -xzf sysklogd-1.5.tar.gz ; cd sysklogd-1.5

	make
	make BINDIR=/sbin install

	# Abud - Fixme - all.log

	cat <<EOF > /etc/syslog.conf
# Begin /etc/syslog.conf
*.* -/var/log/all.log
# End /etc/syslog.conf
EOF

	cd /sources; rm -rf sysklogd-1.5

# 6.54. Sysvinit-2.86
# Upgraded to
# 6.54. Sysvinit-2.88dsf


	startStep 6.54-sysvinit-2.86
	tar -xjf sysvinit-2.88dsf.tar.bz2 ; cd sysvinit-2.88dsf

	sed -i 's@Sending processes@& configured via /etc/inittab@g'  src/init.c

	sed -i -e 's/utmpdump wall/utmpdump/' -e 's/mountpoint.1 wall.1/mountpoint.1/' src/Makefile

	make -C src
	make -C src install

	cat > /etc/inittab << "EOF"
id:3:initdefault:
si::sysinit:/etc/rc.d/init.d/rc sysinit
l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6
ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now
su:S016:once:/sbin/sulogin
1:2345:respawn:/sbin/agetty ttyS0 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
4:2345:respawn:/sbin/agetty tty4 9600
5:2345:respawn:/sbin/agetty tty5 9600
6:2345:respawn:/sbin/agetty tty6 9600
EOF

	cd /sources; rm -rf sysvinit-2.88dsf

# 6.55. Tar-1.22

	startStep 6.55-tar-1.22
	tar -xjf tar-1.22.tar.bz2 ; cd tar-1.22

	./configure --prefix=/usr --bindir=/bin --libexecdir=/usr/sbin
	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make check &> ${LOGS}/check-${LFSSTEP}.log
		#
		#	69 tests were successful.
		#	8 tests were skipped.
		#
	fi

	make install

	cd /sources; rm -rf tar-1.22

# 6.56. Texinfo-4.13a

	# Abud - no docs
	#
	# ./configure --prefix=/usr
	# make
	# make check
	# make install

	# make TEXMF=/usr/share/texmf install-tex
	# cd /usr/share/info
	# rm -v dir

	# for f in *
	# do install-info $f dir 2>/dev/null
	# done

# 6.57. Udev-145


	# Abud - let's try without udev
	# using dev-abud.tar.gz to create a hardcoded /dev

	#	tar -xjf udev-145.tar.bz2 ; cd udev-145

	#	tar -xvf ../udev-config-20090523.tar.bz2

	#	install -dv /lib/{firmware,udev/devices/{pts,shm}}
	#	mknod -m0666 /lib/udev/devices/null c 1 3
	#	mknod -m0600 /lib/udev/devices/kmsg c 1 11
	#	ln -sv /proc/self/fd /lib/udev/devices/fd
	#	ln -sv /proc/self/fd/0 /lib/udev/devices/stdin
	#	ln -sv /proc/self/fd/1 /lib/udev/devices/stdout
	#	ln -sv /proc/self/fd/2 /lib/udev/devices/stderr
	#	ln -sv /proc/kcore /lib/udev/devices/core

	#	./configure --prefix=/usr \
	#		--sysconfdir=/etc --sbindir=/sbin \
	#		--with-rootlibdir=/lib --libexecdir=/lib/udev \
	#		--docdir=/usr/share/doc/udev-145 \
	#		--disable-extras

	#	make
	#	make install

	#	install -m644 -v rules/packages/64-*.rules  /lib/udev/rules.d/
	#	install -m644 -v rules/packages/40-pilot-links.rules  /lib/udev/rules.d/
	#	install -m644 -v rules/packages/40-isdn.rules /lib/udev/rules.d/

	#	cd udev-config-20090523
	#	make install
	
	# Abud - no docs
	# make install-doc
	# make install-extra-doc

	#	cd /sources; rm -rf udev-145

# Added
# 6.49. Libffi-3.2.1  (lfs 8.3)

	startStep 6.49.libffi-3.2.1
	tar -xf libffi-3.2.1.tar.gz; cd libffi-3.2.1
	
	sed -e '/^includesdir/ s/$(libdir).*$/$(includedir)/' \
		-i include/Makefile.in

	sed -e '/^includedir/ s/=.*$/=@includedir@/' \
		-e 's/^Cflags: -I${includedir}/Cflags:/' \
		-i libffi.pc.in

	./configure --prefix=/usr --disable-static --with-gcc-arch=native

	make
	make install

	cd /sources; rm -rf libffi-3.2.1


# 6.58. Vim-7.2

	startStep 6.58-vim-7.2
	tar -xjf vim-7.2.tar.bz2; cd vim72

	patch -Np1 -i ../vim-7.2-fixes-5.patch

	echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
	./configure --prefix=/usr --enable-multibyte

	make

	# Abud - needs visual check
	if [ DD${MKTEST}DD = DDYESDD ]
	then
		make test &> ${LOGS}/check-${LFSFACE}.log
		#
		# Test results:
		#  ALL DONE
		#
	fi

	make install

	ln -sv vim /usr/bin/vi
	for L in /usr/share/man/{,*/}man1/vim.1; do
		ln -sv vim.1 $(dirname $L)/vi.1
	done

	ln -sv ../vim/vim72/doc /usr/share/doc/vim-7.2

	cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc
set nocompatible
set backspace=2
syntax on
if (&term == "iterm") || (&term == "putty")
set background=dark
endif
" End /etc/vimrc
EOF

	# Abud - ????
	# vim -c ':options'
	# set spelllang=en,ru
	# set spell

	cd /sources; rm -rf vim72

# Added
# Linux-3.16.61 perf

	startStep 6.7-"$KERNEL_VERSION"-perf
	tar -xJf "$KERNEL_VERSION".tar.xz; cd "$KERNEL_VERSION"
	if [ "$KERNEL_VERSION" = "linux-3.19.8" ]
	then
		patch -s -p1 < ../linux-3.19.8-perf-builtin-report.patch
	fi
	make -C tools/perf DESTDIR=/usr install
	cd /sources; rm -rf "$KERNEL_VERSION"

# Added bnx2-firmware

	startStep bnx2-firmware

	mkdir -pv /lib/firmware
	tar -C /lib/firmware -xf bnx2-firmware.tgz
	tar -C /lib/firmware -xf bnx2x-firmware.tgz

	cd /sources

# 7.2. LFS-Bootscripts-20090812


	startStep 7.2-lfs-bootscripts-20190312
        tar -xjf lfs-bootscripts-20190312.tar.bz2 ; cd lfs-bootscripts-20190312

        make install

	# No udev
	rm -f /etc/rc.d/rcsysinit.d/S10udev
	rm -f /etc/rc.d/rcsysinit.d/S50udev_retry

	# Running from ram (no need to fscheck)
	rm -f /etc/rc.d/rcsysinit.d/S30checkfs

	# No need of system init script for network and ntp (handled by modeller)
	rm -f /etc/rc.d/rc*.d/S*network
	rm -f /etc/rc.d/rc*.d/K*network

        cd /sources; rm -rf lfs-bootscripts-20190312


# 8.4. GRUB-0.97

## 	No Grub, abud
##	startStep 8.4-grub-0.97
##	tar -xzf grub-0.97.tar.gz; cd grub-0.97
##
##	patch -Np1 -i ../grub-0.97-disk_geometry-1.patch
##	patch -Np1 -i ../grub-0.97-256byte_inode-1.patch
##
##	./configure --prefix=/usr
##
##	make CFLAGS="-march=i486 -mtune=native -Os"
##
##	if [ DD${MKTEST}DD = DDYESDD ]
##	then
##		make check &> ${LOGS}/check-${LFSFACE}.log
##	fi
##
##	make install
##	mkdir -v /boot/grub
##	cp -v /usr/lib/grub/i386-pc/stage{1,2} /boot/grub
##
##	cd /sources; rm -rf grub-0.97
##


# 7.*. Creating System Files

	startStep '7-creating-system-files'


# 7.4. Configuring the setclock Script

	startStep basic-files

	cat > /etc/sysconfig/clock << "EOF"
# Begin /etc/sysconfig/clock
UTC=1
# Set this to any options you might need to give to hwclock,
# such as machine hardware clock type for Alphas.
CLOCKPARAMS=
# End /etc/sysconfig/clock
EOF

# 7.5. Configuring the Linux Console

	cat > /etc/sysconfig/console << "EOF"
# Begin /etc/sysconfig/console
#UNICODE="1"
KEYMAP="us"
#KEYMAP_CORRECTIONS="euro2"
#LEGACY_CHARSET="iso-8859-15"
#FONT="LatArCyrHeb-16 -m 8859-15"
# End /etc/sysconfig/console
EOF

# 7.7. Creating the /etc/inputrc File

	cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>
# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF

# 7.8. The Bash Shell Startup Files

	cat > /etc/profile << "EOF"
export LANG=en_US.iso88591
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/opt/extras/bin:/opt/extras/sbin
export LD_LIBRARY_PATH=/lib:/usr/lib:/opt/extras/lib
EOF

# 7.11. Configuring the localnet Script

	echo "HOSTNAME=abdlfs" > /etc/sysconfig/network

	cat > /etc/hosts << "EOF"
# Begin /etc/hosts (network card version)
127.0.0.1 localhost abdlfs
# End /etc/hosts (network card version)
EOF
	
	# Abud - fixme
	#for NIC in /sys/class/net/eth0 /sys/class/net/lo ; do \
	# INTERFACE=${NIC##*/} udevadm test --action=add $NIC \
	# done

#	Abud - no need for system startup files anymore
#	mkdir -pv /etc/sysconfig/network-devices/ifconfig.eth0

#	cat > /etc/sysconfig/network-devices/ifconfig.eth0/ipv4 << "EOF"
#ONBOOT=yes
#SERVICE=ipv4-static
#IP=192.168.255.254
#GATEWAY=192.168.255.1
#PREFIX=24
#BROADCAST=192.168.255.255
#EOF

# 8.2. Creating the /etc/fstab File

	cat > /etc/fstab << "EOF"
rootfs / rootfs defaults 1 1
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
devpts /dev/pts devpts gid=4,mode=620 0 0
tmpfs /dev/shm tmpfs defaults 0 0
# End /etc/fstab
EOF

	cat > /etc/motd << "EOF"
Welcome to AbdLFS

   - /usr is a read-only squashed file-system.
   - Large packages can be installed in per package directories in /opt
   - Remember:
   -    Reboot will remove everything installed in /opt
   -    To make it permanent move to /storage/0/AbdLFSExtras and devmount will make apropriate links

EOF

# Final Adjusts

	startStep 'Final-Adjusts'


# Abud - Giving a system an init
	cp /sbin/init /

# Compat links
	ln -s /usr/sbin/ethtool /sbin/ethtool
	ln -s /usr/bin/sort /bin/sort
	ln -s /usr/bin/awk /bin/awk

echo; echo "AbdLFS: $(date +%Y%m%d-%H%M%S) - Finished $LFSSCRIPTNAME"; echo
