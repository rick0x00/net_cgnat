#!/bin/bash

# ============================================================ #
# Tool Created date: 06 mar 2023                               #
# Tool Created by: Henrique Silva (rick.0x00@gmail.com)        #
# Tool Name: net_cgnat (OS debian, Native, NfTables)           #
# Description: Script for creation of CGNAT with NFTABLES      #
# License: MIT License                                         #
# Remote repository 1: https://github.com/rick0x00/            #
# Remote repository 2: https://gitlab.com/rick0x00/            #
# ============================================================ #


fence="###########################################################################"
line="---------------------------------------------------------------------------"

echo "$fence"
echo "Install nftables"
echo "$line"
apt update
apt install -y nftables

systemctl enable --now nftables

echo "$fence"
echo "Enable packet forwarding"
echo "$line"
echo "net.ipv4.conf.all.forwarding=1" >> /etc/sysctl.d/IPv4-forwarding.conf
sysctl -p /etc/sysctl.d/IPv4-forwarding.conf

echo "$fence"
echo "Enable Available Kernel Modules for NAT"
echo "$line"
echo "" >> /etc/modules ;
echo "# Start Add modules for best CGNAT" >> /etc/modules ;
for i in $(find /lib/modules/$(uname -r) -name ??*nat* -print | grep -i netfilter |  sed 's/.*\///' | sed 's/\..*\.gz$//; s/\.ko$//'); do 
    echo $i >> /etc/modules ;
done

echo "$fence"
echo "Making Directories"
echo "$line"
mkdir -p /etc/cgnat/confs/

echo "$fence"
echo "Making script for Networking ip configuration"
echo "$line"
touch /etc/cgnat/ipconf.sh
chmod +x /etc/cgnat/ipconf.sh

echo '#!/bin/bash

# Configure LAN
ip address add 100.64.0.1/10 dev ens5

# Configure WAN
ip address add 192.168.122.100/24 dev ens4

' > /etc/cgnat/ipconf.sh

echo "$fence"
echo "Making script for nftables configuration"
echo "$line"
touch /etc/cgnat/cgnat_rulesets.nft
chmod +x /etc/cgnat/cgnat_rulesets.nft

echo '#!/usr/sbin/nft -f

# Delete rules
flush ruleset

# Create nat table
add table nat

# Add the prerouting and postrouting chains to the table
add chain nat prerouting { type nat hook prerouting priority -100 ; policy accept ; }
add chain nat postrouting { type nat hook postrouting priority 100 ; policy accept ; }

# Add the CGNAT INPUT and OUTPUT chains to the table
add chain ip nat CGNATIN
add chain ip nat CGNATOUT

# Define CGNAT chains jumps
add rule ip nat prerouting iifname "ens4" counter jump CGNATIN
add rule ip nat postrouting oifname "ens4" counter jump CGNATOUT

# include more rules
include "/etc/cgnat/confs/conf_wanip_*.nft"
' > /etc/cgnat/cgnat_rulesets.nft

echo "$fence"
echo "Making more rules file"
echo "$line"

echo '
add chain ip nat CGNATOUT_0
add chain ip nat CGNATIN_0
flush chain ip nat CGNATOUT_0
flush chain ip nat CGNATIN_0

# CONFIGURING IP 100.64.0.2
# Configuring Source NAT(SNAT, OUTSIDE CGNAT GRID)
add rule ip nat CGNATOUT_0 ip protocol tcp ip saddr 100.64.0.2 counter snat to 192.168.122.100:1000-3000
add rule ip nat CGNATOUT_0 ip protocol udp ip saddr 100.64.0.2 counter snat to 192.168.122.100:1000-3000
# Configuring Destination NAT(DNAT, INSIDE CGNAT GRID)
add rule ip nat CGNATIN_0 ip protocol tcp ip daddr 192.168.122.100 tcp dport 1000-3000 counter dnat to 100.64.0.2
add rule ip nat CGNATIN_0 ip protocol udp ip daddr 192.168.122.100 udp dport 1000-3000 counter dnat to 100.64.0.2

# CONFIGURING IP 100.64.0.3
# Configuring Source NAT(SNAT, OUTSIDE CGNAT GRID)
add rule ip nat CGNATOUT_0 ip protocol tcp ip saddr 100.64.0.3 counter snat to 192.168.122.100:3000-5000
add rule ip nat CGNATOUT_0 ip protocol udp ip saddr 100.64.0.3 counter snat to 192.168.122.100:3000-5000
# Configuring Destination NAT(DNAT, INSIDE CGNAT GRID)
add rule ip nat CGNATIN_0 ip protocol tcp ip daddr 192.168.122.100 tcp dport 3000-5000 counter dnat to 100.64.0.3
add rule ip nat CGNATIN_0 ip protocol udp ip daddr 192.168.122.100 udp dport 3000-5000 counter dnat to 100.64.0.3

# Configuring nat for more Internet Protocols(ICMP...)
add rule ip nat CGNATOUT_0 counter snat to 192.168.122.100

# Define CGNAT chains jumps
add rule ip nat CGNATOUT ip saddr 100.64.0.0/10 counter jump CGNATOUT_0
add rule ip nat CGNATIN ip daddr 192.168.122.100 counter jump CGNATIN_0
' > /etc/cgnat/confs/conf_wanip_192.168.122.100.nft

echo "$fence"
echo "Making startup script"
echo "$line"
touch /etc/rc.local
chmod +x  /etc/rc.local

echo '#!/bin/bash

echo "============================="
echo "Start Ip Configurations"
echo "+++++++++++++++++++++++++++++"
bash /etc/cgnat/ipconf.sh

echo "============================="
echo "Start NFTABLES configurations"
echo "+++++++++++++++++++++++++++++"
nft -f /etc/cgnat/cgnat_rulesets.nft

' >> /etc/rc.local
