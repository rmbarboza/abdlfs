#!/bin/sh

if [ "$LFS" = "" ]
then
	echo Undefined enviroment variable LFS
	exit -1
fi

if [ -f "$LFS"/bin/env ]
then
	chroot "$LFS" /bin/env -i  HOME=/root TERM="$TERM" PS1='\u:\w chroot \$ ' PATH=/bin:/sbin:/usr/bin /bin/bash --login +h
elif [ -f "$LFS"/usr/bin/env ]
then
	chroot "$LFS" /usr/bin/env -i  HOME=/root TERM="$TERM" PS1='\u:\w chroot \$ ' PATH=/bin:/sbin:/usr/bin /bin/bash --login +h
else
	echo "Could not find neither /bin/env /usr/bin/env"
fi


