# Page XII

cat > version-check.sh << "EOF"
#!/bin/bash
export LC_ALL=C
# Simple script to list version numbers of critical development tools
bash --version | head -n1 | cut -d" " -f2-4
echo "/bin/sh -> `readlink -f /bin/sh`"
echo -n "Binutils: "; ld --version | head -n1 | cut -d" " -f3-
bison --version | head -n1
if [ -e /usr/bin/yacc ];
then echo "/usr/bin/yacc -> `readlink -f /usr/bin/yacc`";
else echo "yacc not found"; fi
bzip2 --version 2>&1 < /dev/null | head -n1 | cut -d" " -f1,6-
echo -n "Coreutils: "; chown --version | head -n1 | cut -d")" -f2
diff --version | head -n1
find --version | head -n1
gawk --version | head -n1
if [ -e /usr/bin/awk ];
then echo "/usr/bin/awk -> `readlink -f /usr/bin/awk`";
else echo "awk not found"; fi
gcc --version | head -n1
/lib/libc.so.6 | head -n1 | cut -d" " -f1-7
grep --version | head -n1
gzip --version | head -n1
#verificar a versao do kernel solicitada pode ser uma abaixo do 2.6
cat /proc/version 
m4 --version | head -n1
make --version | head -n1
patch --version | head -n1
echo Perl `perl -V:version`
sed --version | head -n1
tar --version | head -n1
makeinfo --version | head -n1
echo 'main(){}' > dummy.c && gcc -o dummy dummy.c
if [ -x dummy ]; then echo "Compilation OK";
else echo "Compilation failed"; fi
rm -f dummy.c dummy
EOF
#falta remover o arquivo
#bash version-check.sh


exit

# page 17
#falta a incao para selecionar o disco subistituir o <xxx> e o <yyy> pelo device
mke2fs -jv /dev/<xxx>

# page 18 

mkswap /dev/<yyy>
export LFS=/mnt/lfs
mkdir -pv $LFS
mount -v -t ext3 /dev/<xxx> $LFS

# page 19
#comandos repetidos
mkdir -pv $LFS
mount -v -t ext3 /dev/<xxx> $LFS
mkdir -v $LFS/usr
mount -v -t ext3 /dev/<yyy> $LFS/usr
/sbin/swapon -v /dev/<zzz>

