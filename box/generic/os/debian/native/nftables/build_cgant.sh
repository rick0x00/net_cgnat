#!/bin/bash

# ============================================================ #
# Tool Created date: 16 ago 2024                               #
# Tool Created by: Henrique Silva (rick.0x00@gmail.com)        #
# Tool Name: cgnat install                                     #
# Description: My simple script to provision CGNAT router      #
# License: software = MIT License | hardware = apache          #
# Remote repository 1: https://github.com/rick0x00/net_cgnat   #
# Remote repository 2: https://gitlab.com/rick0x00/net_cgnat   #
# ============================================================ #
# reference content:
# https://wiki.brasilpeeringforum.org/w/CGNAT_na_pratica
# https://debianbrasil.gitlab.io/FiqueEmCasaUseDebian/arquivos/2020-06-03-cgnat-com-nftables.pdf
# https://semanacap.bcp.nic.br/files/apresentacao/arquivo/1613/Apresentacao_CGNAT.pdf
# https://wiki.ispup.com.br/w/CGNAT_na_pr%C3%A1tica
# https://www.youtube.com/watch?v=1q7J3NkQVSc ([#SemanaCap 6] Curso - Conceitos e implementação de CGNAT)
# https://www.youtube.com/watch?v=5uOFtkplDts (FiqueEmCasaUseDebian #23 - CGNAT com NFTables)


sharp="#################################################"
line="--------------------------------------------------"

###### Making a new CGNAT

### setting variables

# interface name of P2P/PTP
# BORDER connection
wan_interface_name="ens4"
# BNG connection
lan_interface_name="ens5"

# IP Address of P2P/PTP
# BORDER connection
ip_wan_addr_ptp="172.16.1.2/30"
ip_wan_gateway_ptp="172.16.1.1"
# BNG connection
ip_lan_addr_ptp="172.16.2.1/30"
ip_lan_gateway_ptp="172.16.2.2"

### variables of CGNAT
# IP Address to outside NAT(WAN)
ip_wan_addr_1="200.200.200.2/24"
# Network Address do inside NAT(LAN)
# RFC 6598 (IANA-Reserved IPv4 Prefix for Shared Address Space)(100.64.0.0/10)
net_cgnat_1="100.64.1.0/24"


wan_interface_member="$wan_interface_name"
wan_cgnat_interface_name="$wan_interface_member"
lan_interface_member="$lan_interface_name"
lan_cgnat_interface_name="$lan_interface_member"


function install_packages() {
	echo $line
	echo "Install packages..."

	#echo "deb http://deb.debian.org/debian bookworm-backports main contrib non-free" > /etc/apt/sources.list.d/bookworm-blackports.list
	apt update -q

	# instalando kernel atualizado
	#apt install -y -q -t bookworm-backports linux-image-amd64
	apt install -y -qq linux-image-amd64
	apt install -y -qq linux-headers-$(uname -r)

	apt install -qq -y nftables 
	apt install -qq -y libnetfilter-conntrack* conntrackd netstat-nat collectd-core
	apt install -y -qq bc ipcalc bmon ethtool tcpdump

}


function create_files() {
	echo $line
	echo "Creating files..."

	# creating base workdir
	mkdir -p /etc/nftables/cgnat/
	mkdir -p /etc/nftables/scripts/

	# copy samples of nftables
	mv /etc/nftables.conf /etc/nftables.old
	cp ./nftables.conf /etc/nftables.conf

	# copy scripts to correct location
	cp ./create_cgnat_networks_rules.sh /etc/nftables/scripts/create_cgnat_networks_rules.sh
	cp ./config_cgnat_networks.sh /etc/nftables/scripts/config_cgnat_networks.sh
	cp ./eth_tunning.sh /etc/nftables/scripts/eth_tunning.sh
	cp ./config_kernel.sh /etc/nftables/scripts/config_kernel.sh
	cp ./set_irq_affinity.sh /etc/nftables/scripts/set_irq_affinity.sh
	cp ./init_cgnat.sh /etc/nftables/scripts/init_cgnat.sh

	# copy network sample files
	cp /etc/network/interfaces /etc/network/interfaces.bkp
	cp ./interfaces /etc/network/interfaces
}

function config_files() {
	echo $line
	echo "Configuring files..."

	# adjust variables of nftables sample file
	sed -i "s|\$wan_cgnat_interface_name|$wan_cgnat_interface_name|" /etc/nftables.conf
	sed -i "s|\$lan_cgnat_interface_name|$lan_cgnat_interface_name|" /etc/nftables.conf

	# adjusting network variables of OS
	sed -i "s|\$wan_interface_name|$wan_interface_name|" /etc/network/interfaces
	sed -i "s|\$lan_interface_name|$lan_interface_name|" /etc/network/interfaces
	sed -i "s|\$wan_interface_member|$wan_interface_member|" /etc/network/interfaces
	sed -i "s|\$lan_interface_member|$lan_interface_member|" /etc/network/interfaces
	sed -i "s|\$wan_addr_and_cidr|$ip_wan_addr_ptp|" /etc/network/interfaces
	sed -i "s|\$wan_gateway|$ip_wan_gateway_ptp|" /etc/network/interfaces
	sed -i "s|\$lan_addr_and_cidr|$ip_lan_addr_ptp|" /etc/network/interfaces
	sed -i "s|\$lan_gateway|$ip_lan_gateway_ptp|" /etc/network/interfaces
	public_net=$(ipcalc ${ip_wan_addr_1} | grep -i "Network:" | awk '{print $2}')
	sed -i "s|\$public_net|${public_net}|" /etc/network/interfaces
	sed -i "s|\$ip_wan_addr_1|${ip_wan_addr_1}|" /etc/network/interfaces
	cgnat_net=$(ipcalc ${net_cgnat_1} | grep -i "Network:" | awk '{print $2}')
	sed -i "s|\$cgnat_net|${cgnat_net}|" /etc/network/interfaces

	# add sample config of CGNAT networks to script
	echo "bash /etc/nftables/scripts/create_cgnat_networks_rules.sh \"1\" \"${ip_wan_addr_1}\" \"${net_cgnat_1}\" \"0\" \"65536\"" >> /etc/nftables/scripts/config_cgnat_networks.sh

	# creating rc.local
	#echo "#!/bin/bash" >> /etc/rc.local
	#echo "bash /etc/nftables/scripts/init_cgnat.sh" >> /etc/rc.local
	#chmod +x /etc/rc.local
}


function execute_configs() {
	echo $line
	echo "Executing configs..."
	echo "enabling nftables"
	systemctl enable nftables

	echo "apply interface configuration"
	systemctl restart networking

	echo "Creating CGNA rules..."
	bash /etc/nftables/scripts/config_cgnat_networks.sh

	echo "starting CGNAT gerais..."
	bash /etc/nftables/scripts/init_cgnat.sh
}

echo $sharp

install_packages;
create_files;
config_files;
execute_configs;

echo $sharp
