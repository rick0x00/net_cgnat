#!/bin/bash

sharp="##################################################################################"
line="----------------------------------------------------------------------------------"

###### CRIANDO UM NOVO CGANT

### definindo variaveis

# WAN
wan_interface_member="ens4"
wan_cgnat_interface_name="$wan_interface_member"
# LAN
lan_interface_member="ens5"
lan_cgnat_interface_name="$lan_interface_member"


# IP para P2P/PTP
# Saida de trafego pela WAN
ip_wan_addr_ptp="172.16.1.2/30"
ip_wan_gateway_ptp="172.16.1.1"
# Entrada de Trafego pela LAN
ip_lan_addr_ptp="172.16.2.1/30"
ip_lan_gateway_ptp="172.16.2.2"


### variaveis do cgnat
# IP de saida do NAT(WAN)
ip_wan_addr_1="200.200.200.2/24"

# Rede de entrada do NAT(LAN)
# RFC 6598 (IANA-Reserved IPv4 Prefix for Shared Address Space)(100.64.0.0/10)
net_cgnat_1="100.64.1.0/24"



function install_packages() {
	echo $line
	echo "INSTALANDO PACOTES..."
	# instalando nftables
	apt install -y nftables

	# INSTALANDO UTILITARIOS

	# adicioandno ao source list um novo repositorio para o debian (bookworm-backports)
	#echo "deb http://deb.debian.org/debian bookworm-backports main contrib non-free" > /etc/apt/sources.list.d/bookworm-blackports.list
	apt update

	# instalando kernel atualizado
	#apt install -y -t bookworm-backports linux-image-amd64
	apt install -y  linux-image-amd64
	apt install -y linux-headers-$(uname -r)

	# instala calculadora
	apt install -y bc 
	# instala calculadora de IP
	apt install -y ipcalc
	# instala ferramenta para monitorar trafego
	apt install -y bmon
	# use o comando amabixo para monitorar
	#bmon -b -p ${wan_interface_name},${lan_interface_name}
	# instalando ferramenta para configuracao de interface
	apt install -y ethtool

}


function create_files() {
	echo $line
	echo "CRIANDO ARQUIVOS..."
	# criando diretorio base
	mkdir -p /etc/nftables/cgnat/
	mkdir -p /etc/nftables/scripts/

	# movendo arquivo padrao de config do nftables
	mv /etc/nftables.conf /etc/nftables.old
	# copiando arquivo de config padrao do nftables para o local adequado
	cp ./nftables.conf /etc/nftables.conf

	# copiando script criador de regras CGNAT
	cp ./create_cgnat_networks_rules.sh /etc/nftables/scripts/create_cgnat_networks_rules.sh
	# copiando arquivo de config de regras CGNAT para o local adequado
	cp ./config_cgnat_networks.sh /etc/nftables/scripts/config_cgnat_networks.sh
	# copiando script de tunning de interface ethernet para o local adequado
	cp ./eth_tunning.sh /etc/nftables/scripts/eth_tunning.sh
	# copiando script de config do kernel
	cp ./config_kernel.sh /etc/nftables/scripts/config_kernel.sh

	# copiando script da intel para fazer CPU Affinity
	cp ./set_irq_affinity.sh /etc/nftables/scripts/set_irq_affinity.sh


	cp /etc/network/interfaces /etc/network/interfaces.bkp
	cp ./interfaces /etc/network/interfaces

	cp ./init_cgnat.sh /etc/nftables/scripts/init_cgnat.sh
}

function config_files() {
	echo $line
	echo "CONFIGURANDO ARQUIVOS..."
	# ajustando variaveis de interface de rede
	sed -i "s|\$wan_cgnat_interface_name|$wan_cgnat_interface_name|" /etc/nftables.conf
	sed -i "s|\$lan_cgnat_interface_name|$lan_cgnat_interface_name|" /etc/nftables.conf

	# ajustando variaveis de interface de rede
	sed -i "s|\$wan_interface_name|$wan_interface_name|" /etc/network/interfaces
	sed -i "s|\$lan_interface_name|$lan_interface_name|" /etc/network/interfaces
	# ajustando variaveis de interface de rede
	sed -i "s|\$wan_interface_member|$wan_interface_member|" /etc/network/interfaces
	sed -i "s|\$lan_interface_member|$lan_interface_member|" /etc/network/interfaces
	# enderecos de WAN
	sed -i "s|\$wan_addr_and_cidr|$ip_wan_addr_ptp|" /etc/network/interfaces
	sed -i "s|\$wan_gateway|$ip_wan_gateway_ptp|" /etc/network/interfaces
	# enderecos de LAN
	sed -i "s|\$lan_addr_and_cidr|$ip_lan_addr_ptp|" /etc/network/interfaces
	sed -i "s|\$lan_gateway|$ip_lan_gateway_ptp|" /etc/network/interfaces
	# enderecos publicos
	public_net=$(ipcalc ${ip_wan_addr_1} | grep -i "Network:" | awk '{print $2}')
	sed -i "s|\$public_net|${public_net}|" /etc/network/interfaces
	# rede CGNAT
	cgnat_net=$(ipcalc ${net_cgnat_1} | grep -i "Network:" | awk '{print $2}')
	sed -i "s|\$cgnat_net|${cgnat_net}|" /etc/network/interfaces

	# definindo atributos para criacao das regras do cgnat
	echo "bash /etc/nftables/scripts/create_cgnat_networks_rules.sh \"1\" \"${ip_wan_addr_1}\" \"${net_cgnat_1}\" \"0\" \"65536\"" >> /etc/nftables/scripts/config_cgnat_networks.sh

	# criando rc.local
	echo "#!/bin/bash" >> /etc/rc.local
	echo "bash /etc/nftables/scripts/init_cgnat.sh" >> /etc/rc.local
	chmod +x /etc/rc.local
}


function execute_configs() {
	echo $line
	echo "EXECUTANDO CONFIGS..."
	echo "habilitando nftables"
	systemctl enable nftables
	echo "fazendo configuracoes gerais"
	bash /etc/nftables/scripts/init_cgnat.sh
	echo "criando regras para rede definida"
	bash /etc/nftables/scripts/config_cgnat_networks.sh
}

echo $sharp

install_packages;
create_files;
config_files;
execute_configs;

echo $sharp
