#!/bin/bash

# Defaults

GW=10.0.0.1
NS=10.0.0.13

function checkIp()
{
	bl=`echo $1 | cut -d'.' -f 4` 
	if [ $? -ne 0 ];
	then
		echo "Invalid IP: $1"
		exit 1;
	fi
}


STORAGE=$1
if [ ! -d "$1" ]
then
	echo "Usage: $0 <storage dir>"
	exit -1
fi

echo "Storage at $STORAGE"

############################################################################## NETWORK

read -p "IP: " ip
checkIp $ip
if ! echo "$ip" | grep / > /dev/null; then
	ip="$ip"/24
fi

read -p "Default gw[$GW]:" GWTRY
if [ ! -z "$GWTRY" ]; then GW=$GWTRY; fi
checkIp $GW

read -p "Name Server[$NS]:" NSTRY
if [ ! -z "$NSTRY" ]; then NS=$NSTRY; fi
checkIp $NS

echo "Setting up networking with ip:$ip, gateway:$GW, dns:$NS "

cat << NETWORK_EOF > $STORAGE/startup.sh
#!/bin/bash
# Created by setup_storage.sh

NETDEV=\`(cd /sys/class/net; for a in *; do echo \$a; done) | grep -e eth0 -e net0 | head -1\`

echo "Using: \$NETDEV, ip:$ip, gw:$GW, dns:$NS"

ip addr add $ip dev \$NETDEV
ip link set \$NETDEV up
ip route add default via $GW
echo "nameserver $NS" > /etc/resolv.conf
NETWORK_EOF

chmod a+x $STORAGE/startup.sh

cp /etc/passwd $STORAGE/
cp /etc/group  $STORAGE/
cp /etc/shadow $STORAGE/

echo "Done"
