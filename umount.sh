#!/bin/sh

umount -vt devpts devpts $LFS/dev/pts
umount -vt tmpfs shm $LFS/dev/shm
umount -vt proc proc $LFS/proc
umount -vt sysfs sysfs $LFS/sys

