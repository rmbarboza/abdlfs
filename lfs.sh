#!/bin/sh

# lfs-s1.sh	-	Toolchain
# lfs-s2.sh	-	Basic System
# lfs-s3-ext.sh	-	Common Extensions (dev/pro)
# lfs-s4.sh	-	Dev Only Extensions

error_trap() {
	echo -e "\nERROR: Error trapped!\n"
	exit -1
}

trap error_trap ERR

LFSSCRIPTNAME=${BASH_SOURCE[0]}

echo; echo "AbdLFS: $(date +%Y%m%d-%H%M%S) - Starting $LFSSCRIPTNAME"; echo

buildver=2.1.0
buildtag=`date +%Y%m%d-%H%M%S`
cdir=`pwd`

KARCH=$(uname -m)

echo "BUILDTAG: $buildtag"
echo "VERSION:  $buildver"

export LFSBASE=$cdir/tmplfs
export LFS=$LFSBASE/dev
export PATH=$PATH:/usr/sbin

rm -rf $LFSBASE
mkdir -pv $LFSBASE
mkdir -pv $LFS

chown -v root.root $LFS

# Toolschain creation
echo; echo 'AbdLFS: Executing lfs-s1.sh';echo
env -i LFS=$LFS HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' WCACHE="$WCACHE" ./lfs-s1.sh

mount -vt devpts devpts $LFS/dev/pts
mount -vt tmpfs shm $LFS/dev/shm
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys

# System creation
echo; echo 'AbdLFS: Executing lfs-s2.sh';echo
chroot "$LFS" $LFS/tools/bin/env -i LFS="$LFS" HOME=/root TERM="$TERM" PS1='\u:\w\$ ' \
	PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin:/prereqs/bin $LFS/tools/bin/bash --login +h \
	-c 'source /lfs-s2.sh'

# Common extensions
echo; echo 'AbdLFS: Executing lfs-s3-ext.sh';echo
chroot "$LFS" /usr/bin/env -i  HOME=/root TERM="$TERM" PS1='\u:\w\$ ' \
	PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin /bin/bash --login +h \
	-c 'source /lfs-s3-ext.sh'

# Bin/lib strip
echo; echo 'AbdLFS: Striping';echo
chroot "$LFS" /tools/bin/env -i HOME=/root TERM="$TERM" PS1='\u:\w\$ ' \
	PATH=/tools/bin \
	/tools/bin/find /usr/lib /lib -type f -exec /tools/bin/strip --strip-unneeded '{}' ';'

chroot "$LFS" /tools/bin/env -i HOME=/root TERM="$TERM" PS1='\u:\w\$ ' \
	PATH=/tools/bin \
	/tools/bin/find /{,usr/}{bin,sbin} -type f -exec /tools/bin/strip --strip-all '{}' ';'

echo "$buildver-$buildtag.$KARCH" > $LFS/etc/abd-lfs-build.info

# Umount to perform backup and clone a production version
umount $LFS/dev/pts
umount $LFS/dev/shm
umount $LFS/proc
umount $LFS/sys

# Save backup copy at this point - before differentiation
#
# Very usefull during development, to avoid the need to rebuild from start every error in next stages.
# But keep commented in commited version
#
### echo; echo "Closing lfs-base-$buildver-$buildtag.tar.bz2";echo
### cd $LFS
### tar -cj --exclude='sources/*' --exclude='extensions/*' --exclude='sources_dev/*' -f $cdir/abd-lfs-base-$buildver-$buildtag.$KARCH.tar.bz2 *
### cd $cdir

# Clone
echo; echo "Cloning dev -> pro";echo
cp -a $LFSBASE/dev $LFSBASE/pro

# Let's do specific dev extensions
### Mount it all again
mount -vt devpts devpts $LFS/dev/pts
mount -vt tmpfs shm $LFS/dev/shm
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys

### Dev extras including sourecs_dev
###
### lfs-s4.sh is reserved to dev only stuff
###
echo; echo 'AbdLFS: Executing lfs-s4.sh';echo
chroot "$LFS" /usr/bin/env -i  HOME=/root TERM="$TERM" PS1='\u:\w\$ ' \
	PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin /bin/bash --login +h \
	-c 'source /lfs-s4.sh'
### End of dev extras part

# Umounting for strip unneeded stuff and packaging
umount $LFS/dev/pts
umount $LFS/dev/shm
umount $LFS/proc
umount $LFS/sys

# Bin/Lib strip again after additional dev packages (including opt now)
echo; echo 'AbdLFS: Striping after dev extras';echo

STRIP_BINDIR=`for a in $LFS/opt/*; do  if [ -e "$a"/bin ]; then b=\`basename $a\`; echo -n /opt/$b/bin " "; fi; done`
STRIP_LIBDIR=`for a in $LFS/opt/*; do  if [ -e "$a"/lib ]; then b=\`basename $a\`; echo -n /opt/$b/lib " "; fi; done`

chroot "$LFS" /tools/bin/env -i HOME=/root TERM="$TERM" PS1='\u:\w\$ ' \
	PATH=/tools/bin \
	/tools/bin/find /usr/lib /lib $STRIP_LIBDIR -type f -exec /tools/bin/strip --strip-debug '{}' ';'

chroot "$LFS" /tools/bin/env -i HOME=/root TERM="$TERM" PS1='\u:\w\$ ' \
	PATH=/tools/bin \
	/tools/bin/find /{,usr/}{bin,sbin} $STRIP_BINDIR -type f -exec /tools/bin/strip --strip-all '{}' ';'


# Removing unneeded stuff from both trees
echo; echo 'AbdLFS: Executing lfs-s5-strip.sh';echo
export LFS=$LFSBASE/pro
env -i LFS=$LFS HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' ./lfs-s5-strip.sh pro
export LFS=$LFSBASE/dev
env -i LFS=$LFS HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' ./lfs-s5-strip.sh dev

echo; echo 'AbdLFS: Saving AbdLFSRemoved Stuff';echo
cd $LFS
if [ -d AbdLFSRemoved ]
then
	tar -cjf $cdir/abd-lfs-"$buildver-$buildtag".$KARCH-removed.tar.bz2 AbdLFSRemoved
fi
rm -rvf "$LFS"/AbdLFSRemoved
cd $cdir


### squashing opt/* (dev only)
echo; echo 'AbdLFS: Executing lfs-s6-opt-squash-opt.sh';echo
cp -v $cdir/lfs-s6-opt-squash.sh "$LFS"/
chroot "$LFS" /usr/bin/env -i  HOME=/root TERM="$TERM" PS1='\u:\w\$ ' \
	PATH=/bin:/sbin:/usr/bin /bin/bash --login +h \
	-c 'source /lfs-s6-opt-squash.sh'
rm -v $LFS/lfs-s6-opt-squash.sh 

# Cpioing both trees
echo; echo "AbdLFS: Cpioing prepro"; echo
cd $LFSBASE/pro
find . | cpio -o -H newc | gzip > $cdir/abd-lfs-"$buildver-$buildtag".$KARCH-prepro.cpio.gz

echo; echo "AbdLFS: Cpioing prepro-devmount"; echo
cd $LFSBASE/pro
ln -s ../init.d/devmount etc/rc.d/rc3.d/S99devmount
find . | cpio -o -H newc | gzip > $cdir/abd-lfs-"$buildver-$buildtag".$KARCH-prepro-devmount.cpio.gz

echo; echo "AbdLFS: Cpioing dev"; echo
cd $LFSBASE/dev
ln -s ../init.d/devmount etc/rc.d/rc3.d/S99devmount
find . | cpio -o -H newc | gzip > $cdir/abd-lfs-"$buildver-$buildtag".$KARCH-dev-full.cpio.gz
cd $cdir

echo; echo "AbdLFS: Cpioing dev-noopt"; echo
cd $LFSBASE/dev
mv sqsh/AbdLFSExtras.sq.img      $cdir/abd-lfs-"$buildver-$buildtag".$KARCH-dev-noopt-AbdLFSExtras.sq.img
find . | cpio -o -H newc | gzip > $cdir/abd-lfs-"$buildver-$buildtag".$KARCH-dev-noopt.cpio.gz
cd $cdir

echo; echo "AbdLFS: $(date +%Y%m%d-%H%M%S) - FINISHED $LFSSCRIPTNAME"; echo

echo abd-lfs-"$buildver-$buildtag".$KARCH-prepro.cpio.gz
echo abd-lfs-"$buildver-$buildtag".$KARCH-prepro-devmount.cpio.gz
echo abd-lfs-"$buildver-$buildtag".$KARCH-dev-full.cpio.gz
echo abd-lfs-"$buildver-$buildtag".$KARCH-dev-noopt.cpio.gz
echo abd-lfs-"$buildver-$buildtag".$KARCH-dev-noopt-AbdLFSExtras.sq.img

echo; echo "AbdLFS: ALL FINISHED"; echo
