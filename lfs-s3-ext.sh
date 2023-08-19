#!/bin/sh

#http://rt.openssl.org/Ticket/Display.html?id=1148&user=guest&pass=guest

#	wget http://invisible-island.net/datafiles/release/byacc.tar.gz
#	wget http://curl.haxx.se/download/archeology/curl-7.12.0.tar.gz
#	wget http://www.tcpdump.org/release/libpcap-1.0.0.tar.gz
#	wget http://www.eecis.udel.edu/~ntp/ntp_spool/ntp4/ntp-4.2/ntp-4.2.4p0.tar.gz
#	wget http://www.linuxfromscratch.org/blfs/downloads/6.3/blfs-bootscripts-20080816.tar.bz2
#	wget http://fcron.free.fr/archives/fcron-3.0.3.src.tar.gz
#	wget https://fedorahosted.org/releases/c/r/cronie/cronie-1.4.4.tar.gz
#	wget http://download.berlios.de/dhcpcd/dhcpcd-3.0.19.tar.bz2
#	wget http://anduin.linuxfromscratch.org/sources/BLFS/6.3/r/rsync-3.0.2.tar.gz
#	wget http://mirrors.unb.br/pub/OpenBSD/OpenSSH/portable/openssh-7.3p1.tar.gz
#	wget http://rpm5.org/files/popt/popt-1.15.tar.gz
#	wget http://downloads.sourceforge.net/hdparm/hdparm-7.7.tar.gz
#	wget http://www.tcpdump.org/release/tcpdump-4.0.0.tar.gz
#	wget http://ftp.gnu.org/gnu/screen/screen-4.0.3.tar.gz
#	wget http://nmap.org/dist-old/nmap-4.11.tgz
#	wget https://nmap.org/dist/nmap-7.40.tar.bz2
#	wget https://www.openssl.org/source/openssl-1.0.1u.tar.gz

#	logrotate-3.7.1.tar.gz collected from redhat srpm ! ! !


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

export EXTRAS=/extensions
export LC_ALL=C
export LANGUAGE=C

cd $EXTRAS

# OpenSSL-1.0.1u

	startStep openssl-1.0.1u
	tar -xzf openssl-1.0.1u.tar.gz ; cd openssl-1.0.1u

	./config --openssldir=/etc/ssl --prefix=/usr shared
	make MANDIR=/usr/share/man

	make MANDIR=/usr/share/man install 
	cp -v -r certs /etc/ssl 
	
	# Abud - no docs
	# install -v -d -m755 /usr/share/doc/openssl-0.9.8g 
	# cp -v -r doc/{HOWTO,README,*.{txt,html,gif}}  /usr/share/doc/openssl-0.9.8g

	cd $EXTRAS; rm -rf openssl-1.0.1u 


# Berkeley Yacc

	startStep byacc-20091027
	tar -xzf byacc.tar.gz; cd byacc-20091027/
	./configure --prefix=/usr
	make
	make install
	cd $EXTRAS; rm -rf byacc-20091027

# Added 20230812
# Expat-2.2.10

	startStep expat-2.2.10
	tar -xf expat-2.2.10.tar.bz2; cd expat-2.2.10
	./configure --prefix=/usr 
	make
	make install
	cd $EXTRAS; rm -rf expat-2.2.10

# Curl

	startStep curl-7.82.0
	tar -xzf curl-7.82.0.tar.gz; cd curl-7.82.0
	./configure 	--prefix=/usr 			\
			--disable-static 		\
			--with-openssl 			\
			--enable-threaded-resolver	\
			--with-ca-path=/etc/ssl/certs
	make
	make install
	cd $EXTRAS; rm -rf curl-7.82.0

# Libpcap-1.0.0
# Upgraded to
# Libpcap-1.7.4o
	
	startStep libpcap-1.7.4
	tar -xzf libpcap-1.7.4.tar.gz; cd libpcap-1.7.4
	./configure --prefix=/usr
	make
	make install
	cd $EXTRAS; rm -rf libpcap-1.7.4

# ntp-4.2.4p0

	startStep ntp-4.2.4p0
	tar -xzf ntp-4.2.4p0.tar.gz; cd ntp-4.2.4p0
	patch -p1 < ../ntp-4.2.4p0-abud.patch
	./configure --prefix=/usr --sysconfdir=/etc --with-binsubdir=sbin
	make
	make install

	# Abud - no docs
	# install -v -m755 -d /usr/share/doc/ntp-4.2.4p0 &&
	#cp -v -R html/* /usr/share/doc/ntp-4.2.4p0/

	cat > /etc/ntp.conf << "EOF"
# Africa
server tock.nml.csir.co.za
# Asia
server 0.asia.pool.ntp.org
# Australia
server 0.oceania.pool.ntp.org
# Europe
server 0.europe.pool.ntp.org
# North America
server 0.north-america.pool.ntp.org
# South America
server 2.south-america.pool.ntp.org
driftfile /var/cache/ntp.drift
pidfile /var/run/ntpd.pid
EOF

	ln -v -sf ../init.d/setclock /etc/rc.d/rc0.d/K46setclock &&
	ln -v -sf ../init.d/setclock /etc/rc.d/rc6.d/K46setclock

	cd $EXTRAS; rm -rf ntp-4.2.4p0


# blfs-bootscripts-20080816.tar.bz2

	startStep blfs-bootscripts-20080816
	tar -xjf blfs-bootscripts-20080816.tar.bz2; cd blfs-bootscripts-20080816
	#	make install-ntp
	make install-fcron
	#	make install-service-dhcpcd
	make install-sshd
	cd $EXTRAS; rm -rf blfs-bootscripts-20080816

# Adjusting boot scripts

	startStep Adjusting-boot-scripts
	sed -i '1,$s/read ENTER//' /etc/rc.d/init.d/functions

# cronie-1.4.4.tar.gz

	startStep cronie-1.4.4
	tar -xf cronie-1.4.4.tar.gz; cd cronie-1.4.4
	./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc

	make
	make install

	mv /etc/rc.d/init.d/fcron /etc/rc.d/init.d/crond
	sed -i -e '1,$s/fcron/crond/g' /etc/rc.d/init.d/crond

	#rc3.d/S40fcron rc6.d/K08fcron rc2.d/S40fcron rc0.d/K08fcron rc5.d/S40fcron rc1.d/K08fcron /rc4.d/S40fcron
	for f in $(find /etc/rc.d -name '*fcron*')
	do
		nname=`echo $f | sed -e 's/fcron/crond/'`
		rm -f $f
		ln -s ../init.d/crond $nname
	done

	mkdir -pv /usr/var/spool/cron
	mkdir -pv /etc/cron.d

	cd $EXTRAS; rm -fr cronie-1.4.4

## fcron-3.0.3
#
#	tar -xzf fcron-3.0.3.src.tar.gz; cd fcron-3.0.3
#
#	cat >> /etc/syslog.conf << "EOF"
## Begin fcron addition to /etc/syslog.conf
#cron.* -/var/log/cron.log
## End fcron addition
#EOF
#
#	/etc/rc.d/init.d/sysklogd reload
#
#	groupadd -g 22 fcron && useradd -d /dev/null -c "Fcron User" -g fcron -s /bin/false -u 22 fcron
#	
#	./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
#		--without-sendmail --with-boot-install=no &&
#
#	make 
#
#	make install
#
#	cd $EXTRAS; rm -rf fcron-3.0.3 
#

# dhcpcd-3.0.19

	startStep dhcpcd-3.0.19
	tar -xjf dhcpcd-3.0.19.tar.bz2 ; cd dhcpcd-3.0.19
	make
	make install

	install -v -d /etc/sysconfig/network-devices/ifconfig.eth0 &&
	cat > /etc/sysconfig/network-devices/ifconfig.eth0/dhcpcd << "EOF"
ONBOOT="yes"
SERVICE="dhcpcd"
DHCP_START="<insert appropriate start options here>"
DHCP_STOP="-k <insert additional stop options here>"
# Set PRINTIP="yes" to have the script print
# the DHCP assigned IP address
PRINTIP="no"
# Set PRINTALL="yes" to print the DHCP assigned values for
# IP, SM, DG, and 1st NS. This requires PRINTIP="yes".
PRINTALL="no"
EOF

	cd $EXTRAS; rm -rf dhcpcd-3.0.19

# rsync-3.0.2

	startStep rsync-3.0.2
	tar -xzf rsync-3.0.2.tar.gz ; cd rsync-3.0.2
	
	# Abud - not going to use as deamon
	# groupadd -g 48 rsyncd &&
	# useradd -c "rsyncd Daemon" -d /home/rsync -g rsyncd -s /bin/false -u 48 rsyncd

	./configure --prefix=/usr 

	make

	make install

	cd $EXTRAS; rm -rf rsync-3.0.2

# openssh-7.3p1 

	startStep openssh-7.3p1
	tar -xzf openssh-7.3p1.tar.gz ; cd openssh-7.3p1
	
	install -v -m700 -d /var/lib/sshd &&
	chown -v root:sys /var/lib/sshd &&
	groupadd -g 50 sshd &&
	useradd -c 'sshd PrivSep' -d /var/lib/sshd -g sshd -s /bin/false -u 50 sshd

	sed -i 's@-lcrypto@/usr/lib/libcrypto.a -ldl@' configure

	sed -i 's@ -ldes@@' configure &&
	./configure --prefix=/usr --sysconfdir=/etc/ssh --datadir=/usr/share/sshd \
		--libexecdir=/usr/lib/openssh --with-md5-passwords \
		--with-privsep-path=/var/lib/sshd \
		--with-xauth=/usr/bin/xauth

	make

	# Abud - need visual check
	#	if test -f /usr/bin/scp
	#	then
	#		mv /usr/bin/scp /usr/bin/scp-bak
	#	fi &&
	#	cp scp /usr/bin/scp &&
	#	make tests 2>&1 | tee check.log
	#	grep "FATAL" check.log
	#
	#	rm /usr/bin/scp &&
	#	if test -f /usr/bin/scp-bak
	#	then
	#		rm /usr/bin/scp-bak
	#	fi &&

	make install

	# Abud - no docs
	#	install -v -m755 -d /usr/share/doc/openssh-4.7p1 &&
	#	install -v -m644 INSTALL LICENCE OVERVIEW README* WARNING.RNG \
	#	/usr/share/doc/openssh-4.7p1

	# Abud - fixme
	# 	echo "PermitRootLogin no" >> /etc/ssh/sshd_config

	cd $EXTRAS; rm -rf openssh-7.3p1

# popt-1.15

	startStep popt-1.15
	# Abud - required by redhat logrotate
	tar -xzf popt-1.15.tar.gz; cd popt-1.15
	./configure --prefix=/usr
	make
	make install
	cd $EXTRAS; rm -rf popt-1.15


# logrotate-3.7.1

	startStep logrotate-3.7.1
	# Using redhat logrotate
	tar -xzf ./logrotate-3.7.1.tar.gz; cd logrotate-3.7.1
	make
	make install
	cd $EXTRAS; rm -rf logrotate-3.7.1
	
# hdparm-7.7

	startStep hdparm-7.7
	tar -xzf hdparm-7.7.tar.gz; cd hdparm-7.7
	make
	make install
	cd $EXTRAS; rm -rf hdparm-7.7

# ethtool

	startStep ethtool-2.6.33-pre1
	tar -xzf ethtool-2.6.33-pre1.tar.gz; cd ethtool-2.6.33-pre1
	./configure --prefix=/usr
	make
	make install
	cd $EXTRAS; rm -rf ethtool-2.6.33-pre1

# tcpdump

	startStep tcpdump-4.9.1
	tar -xzf tcpdump-4.9.1.tar.gz; cd tcpdump-4.9.1
	./configure --prefix=/usr
	make
	make install
	cd $EXTRAS; rm -rf tcpdump-4.9.1

# Screen

	startStep screen-4.0.3
	tar -xzf screen-4.0.3.tar.gz; cd screen-4.0.3
	./configure --prefix=/usr --with-sys-screenrc=/etc/screenrc
	make
	make install
cat <<EOF > /etc/screenrc
startup_message off
#caption always "%-Lw%{= B}%50>%n%f* %t%{-}%+Lw%< %{=b B} %H %{-}  %d/%m/%Y"
vbell off
startup_message off
hardstatus string "[screen %n%?: %t%?] %h"
hardstatus alwayslastline " %c | %w"
pow_detach_msg "Screen session of $LOGNAME $:cr:$:nl:ended."
#caption always "%-Lw%{= B}%50>%n%f* %t%{-}%+Lw%< %{=b B} %H %{-}  %d/%m/%Y"
defscrollback 65000

# Change the xterm initialization string from is2=\E[!p\E[?3;4l\E[4l\E>
# (This fixes the "Aborted because of window size change" konsole symptoms found
#  in bug #134198)
termcapinfo xterm 'is=\E[r\E[m\E[2J\E[H\E[?7h\E[?1;4;6l'
EOF

	cd $EXTRAS; rm -rf screen-4.0.3

# nmap

	startStep nmap-7.40
	tar -xjf nmap-7.40.tar.bz2; cd nmap-7.40
	./configure --prefix=/usr --without-nmapfe
	make
	make install
	cd $EXTRAS; rm -rf nmap-7.40

# lsof

	startStep lsof_4.88
        tar -xjf lsof_4.88.tar.bz2; cd lsof_4.88
        tar -xf lsof_4.88_src.tar; cd lsof_4.88_src;
        ./Configure -n linux
        make
        install -v -m0755 -o root -g root lsof /usr/bin
	cd $EXTRAS; rm -rf lsof_4.88

# quagga
# Removed

#	startStep quagga-0.99.24.1
#	tar -xzf quagga-0.99.24.1.tar.gz; cd quagga-0.99.24.1
#	./configure --enable-vty-group=trafman --enable-vtysh --disable-ospfd --disable-ospf6d --disable-ospfapi --disable-ospfclient --disable-ospf-te --disable-doc
#	make clean
#	make
#	make install-strip
#	cd $EXTRAS; rm -rf quagga-0.99.24.1

# openvpn

	startStep openvpn-2.4.6
	tar -xzf openvpn-2.4.6.tar.gz; cd openvpn-2.4.6
	./configure --enable-iproute2 --disable-lzo --disable-plugin-auth-pam
	make
	make install
	cd $EXTRAS; rm -rf openvpn-2.4.6

# xz-utils

	startStep xz-5.2.2
	tar -xzf xz-5.2.2.tar.gz; cd xz-5.2.2
	./configure --prefix=/usr --libdir=/lib
	make
	make pkgconfigdir=/usr/lib/pkgconfig install
	cd $EXTRAS; rm -rf xz-5.2.2

# Added
# strace-4.9

	startStep strace-4.9
	tar -xJf strace-4.9.tar.xz; cd strace-4.9
	./configure --prefix=/usr
	make
	make install
	cd $EXTRAS; rm -rf strace-4.9

#
#
# Abud... Commented to save for later
# Don't want to put more changes on this
#
#


# Added
# lrzsz-0.12.20

	startStep lrzsz-0.12.20
	tar -xzf lrzsz-0.12.20.tar.gz; cd lrzsz-0.12.20
	./configure --prefix=/usr
	make
	make install
	ln -s lsz /usr/bin/sz
	ln -s lrz /usr/bin/rz
	cd $EXTRAS; rm -rf lrzsz-0.12.20

# Added
# Lm-sensors-3-5-0

	startStep lm-sensors-3-5-0
	tar -xzf lm-sensors-3-5-0.tar.gz; cd lm-sensors-3-5-0
	sed -i -e "s/! which/! whereis/" Makefile
	make
	make install
	cd $EXTRAS; rm -rf lm-sensors-3-5-0

# Added
# Parted-3.1

	startStep parted-3.1
	tar -xf parted-3.1.tar.gz; cd parted-3.1
	./configure \
		--disable-device-mapper --disable-static --prefix=/usr \
		--sbindir=/sbin --bindir=/sbin --libdir=/lib --libexecdir=/lib
	make
	make install
	cd $EXTRAS; rm -rf parted-3.1

# Added
# Iptables-1.4.21

	startStep iptables-1.4.21
	tar -xjf iptables-1.4.21.tar.bz2; cd iptables-1.4.21
	./configure \
	    --prefix=/usr                       \
	    --bindir=/sbin --sbindir=/sbin --sbindir=/sbin  \
	    --libdir=/lib --libexecdir=/lib                 \
	    --with-pkgconfigdir=/usr/lib/pkgconfig
	make
	make install
	cd $EXTRAS; rm -rf iptables-1.4.21

# Added
# libtasn1-4.3
# Needed by gnutls-3.4.5

	startStep libtasn1-4.3
	tar -xf libtasn1-4.3.tar.gz; cd libtasn1-4.3
	./configure --prefix=/usr --disable-static
	make
	make install
	cd $EXTRAS; rm -rf libtasn1-4.3

# Added
# nettle-3.1.1
# Needed by new gnutls-3.4.5

	startStep nettle-3.1.1
	tar -xf nettle-3.1.1.tar.gz; cd nettle-3.1.1
	./configure --prefix=/usr
	make
	make install
	cd $EXTRAS; rm -rf nettle-3.1.1

# Added
# gnutls-3.4.5
# Needed by new wget-2.1

	startStep gnutls-3.4.5
	tar -xf gnutls-3.4.5.tar.xz; cd gnutls-3.4.5
	./configure --prefix=/usr --without-p11-kit
	make
	make install
	cd $EXTRAS; rm -rf wget-1.12

# Added
# Wget-1.12
# Updraded to
# Wget-1.21

	startStep wget-1.21
	tar -xzf wget-1.21.tar.gz; cd wget-1.21
	./configure --prefix=/usr --sysconfdir=/etc --disable-nls --disable-iri
	make
	make install
	cd $EXTRAS; rm -rf wget-1.21

# Added
# Dmidecode-2.11

	startStep dmidecode-2.11
	tar -xzf dmidecode-2.11.tar.gz
	cd dmidecode-2.11
	gunzip -c ../dmidecode_r1.176.patch.gz > ../dmidecode_r1.176.patch
	patch dmidecode.c ../dmidecode_r1.176.patch
	sed -i 	-e '1,$s#PROGRAMS := dmidecode \$(PROGRAMS-\$(MACHINE))#PROGRAMS := dmidecode#g' \
		-e '1,$s#prefix  = /usr/local#prefix  = /usr#g' Makefile
#		-e '1,$s#install : install-bin install-man install-doc#install : install-bin#g' Makefile
	make
	make install
	cd $EXTRAS; rm -rf dmidecode-2.11

# Added
# Pciutils-3.1.4

	startStep pciutils-3.1.4
	tar -xjf pciutils-3.1.4.tar.bz2
	cd pciutils-3.1.4
	sed -i 's#PREFIX=/usr/local#PREFIX=/usr#' Makefile
	make
	make install
#	make PREFIX=$SRCDIR/$1/usr/local install
	cd $EXTRAS; rm -rf pciutils-3.2.1

# Added
# Smartmontools-6.3

	startStep smartmontools-6.3
	tar -xzf smartmontools-6.3.tar.gz
	cd smartmontools-6.3
	./configure --prefix=/usr --sysconfdir=/etc
	make
	make install
	cd $EXTRAS; rm -rf smartmontools-6.3

# Added
# netcat-0.7.1

	startStep netcat-0.7.1
	tar -xf netcat-0.7.1.tar.gz
	cd netcat-0.7.1
	./configure --prefix=/usr
	make
	make install
	cd $EXTRAS; rm -rf netcat-0.7.1

# Added
# bind-9.10.0-P2

	startStep bind-9.10.0-P2
	tar -xf bind-9.10.0-P2.tar.gz
	cd bind-9.10.0-P2

	./configure --prefix=/usr 

	make -C lib/dns
	make -C lib/isc
	make -C lib/bind9
	make -C lib/isccfg
	make -C lib/lwres
	make -C bin/dig

	make -C bin/dig install

	cd $EXTRAS; rm -rf bind-9.10.0-P2

# Added
# fio-2.21
# From https://git.kernel.org/pub/scm/linux/kernel/git/axboe/fio.git/snapshot/fio-2.21.tar.gz

	startStep fio-2.21
	tar -xf fio-2.21.tar.gz
	cd fio-2.21
	./configure --prefix=/usr
	make
	make install
	cd $EXTRAS; rm -rf fio-2.21

# Added
# iputils-s20121221

	startStep iputils-s20121221
	tar -xf iputils-s20121221.tar.bz2
	cd iputils-s20121221
	mv Makefile Makefile.orig
	sed -e 's/USE_GNUTLS=yes/USE_GNUTLS=no/' Makefile.orig > Makefile
	make
	cp arping /bin
	cd $EXTRAS; rm -rf iputils-s20121221

# Added
# minicom-2.8
# From https://salsa.debian.org/minicom-team/minicom/-/archive/2.8/minicom-2.8.tar.gz

	startStep minicom-2.8
	tar -xf minicom-2.8.tar.gz
	cd minicom-2.8
	mv Makefile.in Makefile.in.orig
	sed -e 's/SUBDIRS = doc extras man po lib src/SUBDIRS = doc extras man lib src/' Makefile.in.orig > Makefile.in
	./configure --prefix=/usr
	make
	make install
	cd $EXTRAS; rm -rf minicom-2.8

# Added
# picocom-3.1
# From https://github.com/npat-efault/picocom/archive/refs/tags/3.1.tar.gz

	startStep picocom-3.1
	tar -xf picocom-3.1.tar.gz
	cd picocom-3.1
	make
	strip picocom
	cp picocom /bin
	cp picocom.1 /usr/share/man/man.1
	cd $EXTRAS; rm -rf picocom-3.1

# Added
# Netperf-2.7.0
# From https://github.com/HewlettPackard/netperf/archive/refs/tags/netperf-2.7.0.tar.gz

	startStep netperf-2.7.0
	tar -xf netperf-2.7.0.tar.gz
	cd netperf-netperf-2.7.0
	./configure --prefix=/usr/bin
	make
	make install
	cd $EXTRAS; rm -rf netperf-2.7.0

# Added
# iperf3-3.1.3
# From https://iperf.fr/download/source/iperf-3.1.3-source.tar.gz

	startStep iperf-3.1.3
	tar -xf iperf-3.1.3-source.tar.gz
	cd iperf-3.1.3
	./configure --prefix=/usr
	make
	make install
	cd $EXTRAS; rm -rf iperf-3.1.3

# Added
# pixman-0.22.2
# From https://cairographics.org/releases/pixman-0.22.2.tar.gz

        startStep pixman-0.22.2
        tar -xf pixman-0.22.2.tar.gz
        cd pixman-0.22.2
        ./configure --prefix=/usr
        make
        make install
        cd $EXTRAS; rm -rf pixman-0.22.2

# Added
# qemu-4.2.0

	startStep Python-2.7.15-temporary-for-qemu
	tar -xf Python-2.7.15.tar.xz
	cd Python-2.7.15
	./configure --prefix=/tools/tmppython2
	make
	make install
	cd ..
	rm -rf Python-2.7.15

	startStep glib-2.56.1.tar.xz
	tar -xf glib-2.56.1.tar.xz
	cd glib-2.56.1
	# Avoiding locales
	rm po/LINGUAS
	touch po/LINGUAS
	# Adding /tools/bin to access msgfmt (from toolchain gettext)
	SAVEDPATH=$PATH
	export PATH=$PATH:/tools/bin
	./configure --prefix=/usr --disable-libmount --with-pcre=internal --with-python=/tools/tmppython2/bin/python --disable-selinux --enable-gtk-doc-html=no --enable-gtk-doc=no
	make
	make install
	export PATH=$SAVEDPATH
	cd ..
	rm -rf glib-2.56.1

	startStep qemu-4.2.0
	tar -xf qemu-4.2.0.tar.xz
	cd qemu-4.2.0

	rm -f pc-bios/edk2*
	touch pc-bios/edk2-licenses.txt

	mkdir build
	cd build

	export QEMU_ARCH=x86_64-softmmu
	../configure --python=/tools/tmppython2/bin/python \
		--prefix=/usr \
		--sysconfdir=/etc \
		--target-list=$QEMU_ARCH \
		--audio-drv-list=oss \
		--disable-curl \
		--disable-curses \
		--enable-virtfs \
		--disable-capstone \
		--disable-qom-cast-debug \
		--disable-cloop \
		--disable-dmg \
		--disable-parallels \
		--disable-sheepdog \
		--enable-trace-backend=nop
	sed -ie 's/TOOLS=qemu-ga.*/TOOLS=qemu-ga$(EXESUF) qemu-img$(EXESUF) fsdev\/virtfs-proxy-helper$(EXESUF)/' config-host.mak
	make
	make install

	QS=/usr/share/qemu
	for x in $QS/*hppa* $QS/*ppc* $QS/*sparc* $QS/*s390* $QS/*slof.bin $QS/*u-boot* $QS/*skiboot* $QS/*riscv* $QS/trace-events-all $QS/*petalogix* $QS/palcode-clipper $QS/qemu-nsis.bmp 
	do
		rm -vf $x
	done

	rm -rf $QS/firmware

	ls $QS/keymaps/* | grep -v en-us | while read x; do rm -vf $x; done

	cd ..
	cd ..
	rm -rf qemu-4.2.0

# Added
# libcaca-0.99.beta19
# from http://caca.zoy.org/files/libcaca/libcaca-0.99.beta19.tar.gz

	startStep libcaca-0.99.beta19
	tar -xf libcaca-0.99.beta19.tar.gz
	cd libcaca-0.99.beta19
	./configure --prefix=/usr --disable-network --disable-static
	make
	make install
	rm -fv /usr/bin/cacademo /usr/bin/cacaserver
	cd ..
	rm -rf libcaca-0.99.beta19

#
# devsetup
#

# Move in ablbench

	startStep Ablbench

	mkdir -pv /usr/share/abud
	cp -vf /devsetup/abench*.tar.gz /usr/share/abud

# Storage-startup

	startStep Storage-startup

	cp -vf /devsetup/devmount /etc/rc.d/init.d/devmount
	chmod a+x /etc/rc.d/init.d/devmount
	#Install, but does not activate (will be done in lfs.sh, just before cpio)
	#ln -s ../init.d/devmount /etc/rc.d/rc3.d/S99devmount

	cp -vf /devsetup/devsetup.sh /bin
	chmod a+x /bin/devsetup.sh

# Defaulit-localtime

	startStep Default-localtime
	# Install a default localtime
	cp -av /devsetup/default-localtime /etc/localtime


# Added
# sqshlabel

	startStep sqshlabel
	cd /devsetup
	gcc -o sqshlabel sqshlabel.c
	strip -s sqshlabel 
	mv sqshlabel /sbin


echo; echo "AbdLFS: $(date +%Y%m%d-%H%M%S) - Finished $LFSSCRIPTNAME"; echo
