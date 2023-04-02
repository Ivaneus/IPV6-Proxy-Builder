#!/bin/bash

if ping6 -c3 google.com &>/dev/null; then
  echo "Your server is ready to set up IPv6 proxies!"
else
  echo "Your server can't connect to IPv6 addresses."
  echo "Please, connect ipv6 interface to your server to continue."
  exit 1
fi
rm -rf ~/ipv6
mkdir ~/ipv6
#确保使用安装程序目录
cd ~/ipv6
####必要组件
echo "-------------------------------------------------"
echo ">-- Updating packages and installing dependencies"
apt-get update >/dev/null 2>&1
apt-get -y install gcc g++ make bc pwgen git curl wget net-tools >/dev/null 2>&1
####
echo "Try to get your Network info..."
sleep 1
IPV6_INTERFACE=$(ip -6 route show | grep "/" | grep -v "fe80" |  cut -d " " -f 3)
echo $IPV6_INTERFACE
HOST_IPV4_ADDR=$(curl -4 --silent --interface $IPV6_INTERFACE ip.sb)
echo $HOST_IPV4_ADDR
IPV6_SUBNET=$(ip -6 route show | grep "/" | grep -v "fe80" |  cut -d " " -f 1)
echo $IPV6_SUBNET
    PROXY_NET_MASK=$(echo $IPV6_SUBNET | awk -F/ '{print $2}')
	PROXY_NETWORK=$(echo $IPV6_SUBNET | awk -F/ '{print $1}')
    if [ $PROXY_NET_MASK = "64" ] || [ $PROXY_NET_MASK = "48" ] || [ $PROXY_NET_MASK = "32" ] || [ $PROXY_NET_MASK = "29" ]; then
	   echo "● Your IPV6 Network is:   $PROXY_NETWORK"
	   echo "● Your IPV6 Subnet is:   $PROXY_NET_MASK"	   
    else
	   echo "IPV6 NET_MASK unrecognized, Please Check and Try Again !"
    exit 0
	fi   

####
echo "↓ Port numbering start (default 5000):"
read PROXY_START_PORT
if [[ ! "$PROXY_START_PORT" ]]; then
  PROXY_START_PORT=5000
fi
echo "Port numbering start at  $PROXY_START_PORT"

####
echo "↓ Proxies count (default 1):"
read PROXY_COUNT
if [[ ! "$PROXY_COUNT" ]]; then
  PROXY_COUNT=1
fi
echo "Port Total Amount:  $PROXY_COUNT"

####
echo "↓ Proxies split count (default 5000):"
read PROXY_SPLIT_COUNT
if [[ ! "$PROXY_SPLIT_COUNT" ]]; then
  PROXY_SPLIT_COUNT=5000
fi
echo "Port Split Amount:  $PROXY_SPLIT_COUNT"

####
echo "↓ Proxies protocol (1. HTTP   2. SOCKS):"
read PROXY_PROTOCOL_SET
while true :
do
if [ $PROXY_PROTOCOL_SET = "1" ]; then
  PROXY_PROTOCOL="http"
  echo "Proxy Protocol Type:  $PROXY_PROTOCOL"
  break
elif [ $PROXY_PROTOCOL_SET = "2" ]; then
  PROXY_PROTOCOL="socks"
  echo "Proxy Protocol Type:  $PROXY_PROTOCOL"
  break
else
echo "Proxies protocol unrecognized, try again!"
echo "↓ Proxies protocol (1. HTTP   2. SOCKS):"
read PROXY_PROTOCOL_SET
fi
done

####
echo "↓ Proxies IP Mode (1. OnlyIPV6   2.PreferIPV6):"
read PROXY_IP_MODE_SET
while true :
do
if [ $PROXY_IP_MODE_SET = "1" ]; then
  PROXY_IP_MODE="6"
  echo "Proxies IP Mode:  $PROXY_IP_MODE"
  break
elif [ $PROXY_IP_MODE_SET = "2" ]; then
  PROXY_IP_MODE="64"
  echo "Proxies IP Mode:  $PROXY_IP_MODE"
  break
else
echo "Proxies IP Mode unrecognized, try again!"
echo "↓ Proxies IP Mode (1. OnlyIPV6   2.PreferIPV6):"
read PROXY_IP_MODE_SET
fi
done

####
sleep 1
clear
PROXY_NETWORK=$(echo $PROXY_NETWORK | awk -F:: '{print $1}')
let PROXY_END_PORT=$PROXY_COUNT+$PROXY_START_PORT
echo "● IPV6 Network:  $PROXY_NETWORK"
echo "● IPV6 Network Mask:  $PROXY_NET_MASK"
echo "● IPV6 Network Interface:  $IPV6_INTERFACE"
echo "● Outbound IPv4 Address:  $HOST_IPV4_ADDR"
echo "● Proxies Protocol Type:  $PROXY_PROTOCOL"
echo "● Proxies Total Ports:  $PROXY_COUNT"
echo "● Proxies Ports Range:  $PROXY_START_PORT-$PROXY_END_PORT"
echo "● Proxies Ports Split Amount:  $PROXY_SPLIT_COUNT"

####
echo ">-- Setting up sysctl.conf"
cat >>/etc/sysctl.conf <<END
net.ipv6.conf.$IPV6_INTERFACE.proxy_ndp=1
net.ipv6.conf.all.proxy_ndp=1
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.all.forwarding=1
net.ipv6.ip_nonlocal_bind=1
net.ipv4.ip_local_port_range=1024 65535
net.ipv6.route.max_size=409600
net.ipv4.tcp_max_syn_backlog=4096
net.ipv6.neigh.default.gc_thresh3=102400
kernel.threads-max=1200000
kernel.max_map_count=6000000
vm.max_map_count=6000000
kernel.pid_max=2000000
END
sort -u /etc/sysctl.conf -o /etc/sysctl.conf

####
echo ">-- Setting up logind.conf"
echo "UserTasksMax=1000000" >>/etc/systemd/logind.conf
sort -u /etc/systemd/logind.conf -o /etc/systemd/logind.conf

####
echo ">-- Setting up system.conf"
cat >/etc/systemd/system.conf <<END
DefaultMemoryAccounting=no
DefaultTasksAccounting=no
DefaultLimitDATA=infinity
DefaultLimitSTACK=infinity
DefaultLimitCORE=infinity
DefaultLimitRSS=infinity
DefaultLimitAS=infinity
DefaultLimitMEMLOCK=infinity
DefaultLimitNOFILE=102400
DefaultLimitNPROC=102400
DefaultLimitSIGPENDING=1200000
UserTasksMax=1000000
DefaultTasksMax=1000000

END
sort -u /etc/systemd/system.conf -o /etc/systemd/system.conf
sed -i '1i\[Manager]' /etc/systemd/system.conf

####
echo ">-- Setting up ndppd"
apt-get -y install ndppd >/dev/null 2>&1
#git clone --quiet https://github.com/DanielAdolfsson/ndppd.git >/dev/null
#cd ndppd
#make -k all >/dev/null 2>&1
#make -k install >/dev/null 2>&1	
cat >/etc/ndppd.conf <<END
route-ttl 30000
proxy $IPV6_INTERFACE {
   router no
   timeout 500
   ttl 30000
   rule ${PROXY_NETWORK}::/${PROXY_NET_MASK} {
      static
   }
}
END

####
echo ">-- Setting up 3proxy"
git clone --quiet https://github.com/3proxy/3proxy.git >/dev/null
cd 3proxy
chmod +x src/
touch src/define.txt
echo "#define ANONYMOUS 1" >src/define.txt
sed -i '31r src/define.txt' src/proxy.h
sed  -i '/LimitNPROC/d' scripts/3proxy.service
sed  -i '/LimitNOFILE/d' scripts/3proxy.service
make -f Makefile.Linux >/dev/null 2>&1
make -f Makefile.Linux install >/dev/null 2>&1
cat >/etc/3proxy/3proxy.cfg <<END
#!/bin/bash
#daemon
log /var/log/3proxy/log-%Y%m%d.log D
logformat "L[%Y-%m-%d %H:%M:%S.%.] - "Proxy":["type": %N, "port": %p], "Error":["code": %E}, "Auth":["user": %U], "Client":["ip": %C, "port": %c], "Server":["ip": %R, "port": %r], "Bytes":["sent": %O, "received": %I], "Request":["hostname": %n], "Message":[ %T]"
rotate 30
maxconn 666
nserver 8.8.8.8
nserver 1.1.1.1
nscache 65535
nscache6 65535
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 102400
bandlimin 60000000 * * * 80
bandlimin 60000000 * * * 443
bandlimout 30000000 * * * 80
bandlimout 30000000 * * * 443
flush
auth strong
END

# Generating 3proxy IPv6 addresses
echo ">-- Generating IPv6 addresses"
cd ~/ipv6 && mkdir proxylist
P_VALUES=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
PROXY_GENERATING_INDEX=1
GENERATED_PROXY=""

generate_proxy() {
  a=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}
  b=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}
  c=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}
  d=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}
  e=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}
  f=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}
  
if [ $PROXY_NET_MASK = "64" ]; then
echo "$PROXY_NETWORK:$a:$b:$c:$d">>~/ipv6/ip.list 
elif [ $PROXY_NET_MASK = "48" ];then
echo "$PROXY_NETWORK:$a:$b:$c:$d:$e">>~/ipv6/ip.list 
elif [ $PROXY_NET_MASK = "32" ];then
echo "$PROXY_NETWORK:$a:$b:$c:$d:$e:$f">>~/ipv6/ip.list 
#elif [ $PROXY_NET_MASK = "29" ];then #待更新支持/29
#echo "$PROXY_NETWORK:$a:$b:$c:$d:$e:$f">>~/ipv6/ip.list 
else
echo "Warnning: IPV6 Address Generating Failed!"
fi

}

while [ "$PROXY_GENERATING_INDEX" -le $PROXY_COUNT ]; do
  generate_proxy
  let "PROXY_GENERATING_INDEX+=1"
done

# Generating 3proxy users&ports
CURRENT_PROXY_PORT=${PROXY_START_PORT}
for e in $(cat ~/ipv6/ip.list); do
  echo "$([ $PROXY_PROTOCOL == "socks" ] && echo "socks" || echo "proxy") -$PROXY_IP_MODE -olSO_REUSEADDR,SO_REUSEPORT -ocTCP_TIMESTAMPS,TCP_NODELAY -osTCP_NODELAY -n -a -p$CURRENT_PROXY_PORT -i$HOST_IPV4_ADDR -e$e" >>~/ipv6/proxy.list
  #echo "$PROXY_PROTOCOL://$([ "$PROXY_LOGIN" ] && echo "$PROXY_LOGIN:$PROXY_PASS@" || echo "")$HOST_IPV4_ADDR:$CURRENT_PROXY_PORT" >>~/ipv6/tunnels.txt
  let "CURRENT_PROXY_PORT+=1"
done
cd ~/ipv6/proxylist
split -l $PROXY_SPLIT_COUNT ~/ipv6/proxy.list -d -a 3 proxy_
usernum=1
for file in ~/ipv6/proxylist/*
do
echo $file
if [ -f $file ]; then
Randompwd=$(head /dev/urandom |cksum |md5sum |cut -c 1-16)
startport=$(sed -n '1p' $file | awk '{print $(NF-2)}' | sed 's/-p//')
endport=$(sed -n '$p' $file | awk '{print $(NF-2)}' | sed 's/-p//')
sed -i "1i\allow proxyuser$usernum" $file
sed -i "1i\users proxyuser$usernum:CL:$Randompwd" $file
sed -i '$a\flush' $file
echo "$([ $PROXY_PROTOCOL == "socks" ] && echo "socks5" || echo "http")://proxyuser$usernum:$Randompwd@$HOST_IPV4_ADDR:$startport-$endport" >>~/ipv6/tunnels.txt
let "usernum+=1"
fi
done
cat ~/ipv6/proxylist/proxy_* >>/etc/3proxy/3proxy.cfg


####
echo ">-- Setting up rc.local"
if [ -f "/etc/rc.local" ];then
  chattr -R -i /etc/rc.local
  chattr -R -e /etc/rc.local
fi
#cat >>/etc/rc.local <<END
#!/bin/bash
#ip route add local ${PROXY_NETWORK}::/${PROXY_NET_MASK} dev $IPV6_INTERFACE
#END
#  else
#cat >/etc/rc.local <<END
#!/bin/bash
#ip route add local ${PROXY_NETWORK}::/${PROXY_NET_MASK} dev $IPV6_INTERFACE
#END
#fi
#sort -u /etc/rc.local -o /etc/rc.local
#sed -i 's/exit 0//' /etc/rc.local
cat >/etc/rc.local <<END
#!/bin/bash
ip route add local ${PROXY_NETWORK}::/${PROXY_NET_MASK} dev $IPV6_INTERFACE
exit 0
END
cat >/usr/bin/proxy6 <<END
#!/bin/bash
cat /root/ipv6/tunnels.txt
END
chmod +x /etc/rc.local
chmod +x /usr/bin/proxy6
systemctl enable --now rc-local >/dev/null 2>&1
####
chmod -R 777 ~/ipv6
echo "Finishing"


