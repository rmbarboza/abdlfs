#!/bin/sh

EXPORT LFS=/mnt/lfs

groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs

cat > ~lfs/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

# page 31
cat > ~lfs/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
EOF

chown -v lfs.lfs ~lfs/.bash_profile
chown -v lfs.lfs ~lfs/.bashrc

chown -v lfs.lfs $LFS
ln -sv $LFS/tools /
