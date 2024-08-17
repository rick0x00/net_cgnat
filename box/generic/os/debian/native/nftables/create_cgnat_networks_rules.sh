#!/bin/bash
echo "CRIANDO REGRAS PARA CLIENTES CGNAT..."
echo "Executando: #bash /etc/nftables/scripts/create_cgnat_networks_rules.sh  \"$1\" \"$2\" \"$3\" \"$3\" \"$4\" \"$5\" \"$6\" \"$7\""
echo "INICIANDO SCRIPT"

# bash /etc/nftables/create_cgnat_networks_rules.sh "indice" "public_ip" "private_cgnat_network" "start_port" "end_port" "start_ip" "end_ip"

#### tratando argumentos de entrada

argx=$1

# ip publico de saida do nat
arg1=$2
# rede cgnat
arg2=$3

# numero minimo de porta
arg3=$4
# numero maximo de porta
arg4=$5

# ip de host minimo
arg5=$6
# ip de host maximo
arg6=$7

if [ -z $argx ] || [ -z $arg1 ] || [ -z $arg2 ] || [ -z $arg3 ] || [ -z $arg4 ] ; then
	echo "ERROR: FALTA DE ARGUMENTOS"
	exit 1
fi

echo "CONFIGURANDO VARIAVEIS"
## guardando a hora
hora_agora=$(date --iso-8601="s")

# Endereco IP PUBLICO onde a rede cgnat especificada usara
#ip_wan_addr="200.200.200.2/24"
ip_wan_addr="$arg1"

# garante que somente o endereco estara na variavel
ip_wan_addr=$(ipcalc $ip_wan_addr | grep -i "Address:" | awk '{print $2}')

# rede cgant que deve ser utilizada(ip/cidr)
#net_cgnat="100.64.1.0/24"
net_cgnat="$arg2"

# garante que somente o endereco estara na variavel
ip_cgnat_addr=$(ipcalc $net_cgnat | grep -i "Address:" | awk '{print $2}')

# extrai o prefixo de rede do endereço cgnat
net_cgnat_prefix=$(echo $ip_cgnat_addr | sed -e "s/^\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b$/\1.\2.\3./")
# extrai o indice da rede do cgnat para o ip publico especificado
net_cgnat_indice=$(echo $ip_cgnat_addr | sed -e "s/^\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b$/\3/")

#echo $net_cgnat_prefix
#echo $net_cgnat_indice
#exit

ip_predef_min=$arg5
ip_predef_max=$arg6

# verificando se existe ip minimo e maximo predefinido e fazendo o que e necessario
if [ -n "$ip_predef_min" ] && [ -n "$ip_predef_max" ] ; then
	echo "IP minimo e maximo predefinido"
	ip_cgnat_addr_min=$ip_predef_min
	ip_cgnat_addr_max=$ip_predef_max
	ip_num_min=$(echo $ip_cgnat_addr_min | sed -e "s/^\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b$/\4/")
	ip_num_max=$(echo $ip_cgnat_addr_max | sed -e "s/^\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b$/\4/")
	numero_clientes=$(echo ${ip_num_max}-${ip_num_min}+1 | bc)
else
	echo "IP minimo e maximo NAO predefinido"
	# extraindo host maximo e minimo
	ip_cgnat_addr_min=$(ipcalc $net_cgnat | grep -i "HostMin" | awk '{print $2}')
	ip_cgnat_addr_max=$(ipcalc $net_cgnat | grep -i "HostMax" | awk '{print $2}')
	ip_num_min=$(echo $ip_cgnat_addr_min | sed -e "s/^\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b$/\4/")
	ip_num_max=$(echo $ip_cgnat_addr_max | sed -e "s/^\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b$/\4/")
	# quantidade de cliente no CGNAT por rede especificada
	#numero_clientes="31"
	#numero_clientes=$(ipcalc $net_cgnat | grep -i "Hosts" | awk '{print $2}')
	numero_clientes=$(echo ${ip_num_max}-${ip_num_min}+1 | bc)

fi	
ip_cgnat_addr_broadcast=$(ipcalc $net_cgnat | grep -i "Broadcast" | awk '{print $2}')

#exit

# numero maximo de portas que deve ser alocado para os clientes da rede especificada
#min_port="1"
min_port="$arg3"
#max_port="65537"
max_port="$arg4"

delta_port=$(echo ${max_port}-${min_port} | bc)

# quantidade de portas reservada para cada cliente
#delta_port_por_cliente="2048"
delta_port_por_cliente=$(echo $delta_port/$numero_clientes | bc)


# se 1 escreve as regras, se nao somente calcula para validar se existe algum erro na quantidaded de portas por ip
write_on="1"
# indice do cgnat, geralmente definido pelo 3 octeto do endereco ipv4
#indice_cgnat="$net_cgnat_indice"
indice_cgnat="$argx"


# definindo diretorio/nome de arquivos de configuracao
file_name="regras_cgnat_${ip_cgnat_addr}.nft"
file_local="/etc/nftables/cgnat/"
file_local_and_name="${file_local}${file_name}"

echo "---------------------------------------"
echo "# IP PUBLICO: ${ip_wan_addr};"
echo "# IP REDE CGNAT: ${net_cgnat};"
echo "# IP host Minimo Predefinido: ${ip_predef_min};"
echo "# IP host Maximo Predefinido: ${ip_predef_max};"
echo "# IP Host Minimo: ${ip_cgnat_addr_min};"
echo "# IP Host Maximo: ${ip_cgnat_addr_max};"
echo "# IP Broadcast: ${ip_cgnat_addr_broadcast};"
echo "# Numero de Hosts: $numero_clientes;"
echo "# Numero inicial de porta: $min_port;"
echo "# Numero final de porta: $max_port;"
echo "# Numero de portas uteis: $delta_port;"
echo "# Numero de Portas por cliente: $delta_port_por_cliente;"
echo "---------------------------------------"

#criando diretorio base
echo "CRIANDO DIRETORIO BASE"
mkdir -p $file_local


function create_rules() {
# criando primeiras regras base para o nftables
if [ $write_on -eq 1 ]; then
	echo "# ----- INDICE ${indice_cgnat} -----"
	echo "# Arquivo criando em: $hora_agora"
	echo ""
	echo "# IP PUBLICO: ${ip_wan_addr};"
	echo "# IP REDE CGNAT: ${net_cgnat};"
	echo "# IP host Minimo Predefinido: ${ip_predef_min};"
	echo "# IP host Maximo Predefinido: ${ip_predef_max};"
	echo "# IP Host Minimo: ${ip_cgnat_addr_min};"
	echo "# IP Host Maximo: ${ip_cgnat_addr_max};"
	echo "# IP Broadcast: ${ip_cgnat_addr_broadcast};"
	echo "# Numero de Hosts: $numero_clientes;"
	echo "# Numero inicial de porta: $min_port;"
	echo "# Numero final de porta: $max_port;"
	echo "# Numero de portas uteis: $delta_port;"
	echo "# Numero de Portas por cliente: $delta_port_por_cliente;"
	echo ""
	echo "define WAN_IP_ADDR_${indice_cgnat} = $ip_wan_addr"
	echo "define NET_CGNAT_${indice_cgnat} = $net_cgnat"
	echo "add chain ip cgnat CGNAT_OUT_${indice_cgnat}"
	echo "add chain ip cgnat CGNAT_IN_${indice_cgnat}"
	echo "flush chain ip cgnat CGNAT_OUT_${indice_cgnat}"
	echo "flush chain ip cgnat CGNAT_IN_${indice_cgnat}"
	echo "add rule ip cgnat CGNAT_IN ip daddr \$WAN_IP_ADDR_${indice_cgnat} counter jump CGNAT_IN_${indice_cgnat}"
	echo "add rule ip cgnat CGNAT_OUT ip saddr \$NET_CGNAT_${indice_cgnat} counter jump CGNAT_OUT_${indice_cgnat}"
	echo ""
else
	echo "# calculando"
fi

for ((cliente=${ip_num_min}; cliente<=${ip_num_max}; cliente++)); do
	# calculando portas
	if [ $cliente -eq ${ip_num_min} ] ; then
		#porta_start="1"
		porta_start="$min_port"
	else
		porta_start=$(echo $porta_end+1 | bc ;)
	fi;
	porta_end=$(echo $porta_start+$delta_port_por_cliente-1 | bc ;)
	# verificando porta maxima
	if [ $porta_end -gt $max_port ] ; then
		echo "# ERROR: limite de porta excedido($max_port): $porta_end"
		exit 1;
	fi;
	# criando regras do nftables
	if [ $write_on -eq 1 ]; then
		echo "# CLIENTE: ${net_cgnat_prefix}${cliente}; PORTAS: ${porta_start}-${porta_end};"
		echo "add rule ip cgnat CGNAT_IN_$indice_cgnat ip daddr \$WAN_IP_ADDR_${indice_cgnat} tcp dport ${porta_start}-${porta_end} counter dnat to ${net_cgnat_prefix}${cliente}"
		echo "add rule ip cgnat CGNAT_IN_$indice_cgnat ip daddr \$WAN_IP_ADDR_${indice_cgnat} udp dport ${porta_start}-${porta_end} counter dnat to ${net_cgnat_prefix}${cliente}" 
		echo "add rule ip cgnat CGNAT_OUT_$indice_cgnat ip protocol tcp ip saddr ${net_cgnat_prefix}${cliente} counter snat to \$WAN_IP_ADDR_${indice_cgnat}:${porta_start}-${porta_end}"
		echo "add rule ip cgnat CGNAT_OUT_$indice_cgnat ip protocol udp ip saddr ${net_cgnat_prefix}${cliente} counter snat to \$WAN_IP_ADDR_${indice_cgnat}:${porta_start}-${porta_end}"
	else
		echo -n "."
	fi
done;

# finalizando regras nftables
if [ $write_on -eq 1 ]; then
	# ADD GRANULATED RULES
	echo "# tudo que nao e TCP ou UDP"
	echo "add rule ip cgnat CGNAT_OUT_$indice_cgnat counter snat to \$WAN_IP_ADDR_${indice_cgnat}"
fi

}


echo "CRIANDO REGRAS"
#create_rules
create_rules > ${file_local_and_name}

echo "CRIANDO ARQUIVO \"${file_local_and_name}\""
