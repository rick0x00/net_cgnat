#!/bin/bash

echo "CREATING RULES FOR CGNAT CLIENTS..."
echo "Running: #bash /etc/nftables/scripts/create_cgnat_networks_rules.sh \"$1\" \"$2\" \"$3\" \"$3\" \"$4\" \"$5\" \"$6\" \"$7\""
echo "STARTING SCRIPT"

# bash /etc/nftables/create_cgnat_networks_rules.sh "index" "public_ip" "private_cgnat_network" "start_port" "end_port" "start_ip" "end_ip"

#### Handling input arguments

argx=$1

# Public IP for NAT outbound
arg1=$2
# CGNAT network
arg2=$3

# Minimum port number
arg3=$4
# Maximum port number
arg4=$5

# Minimum host IP
arg5=$6
# Maximum host IP
arg6=$7

if [ -z $argx ] || [ -z $arg1 ] || [ -z $arg2 ] || [ -z $arg3 ] || [ -z $arg4 ] ; then
    echo "ERROR: MISSING ARGUMENTS"
     1
fi


echo "CONFIGURING VARIABLES"
## storing the current time
current_time=$(date --iso-8601="s")

# PUBLIC IP ADDRESS where the specified CGNAT network will use
#ip_wan_addr="200.200.200.2/24"
ip_wan_addr="$arg1"

# ensure that only the address is in the variable
ip_wan_addr=$(ipcalc $ip_wan_addr | grep -i "Address:" | awk '{print $2}')

# CGNAT network to be used (ip/cidr)
#net_cgnat="100.64.1.0/24"
net_cgnat="$arg2"

# ensure that only the address is in the variable
ip_cgnat_addr=$(ipcalc $net_cgnat | grep -i "Address:" | awk '{print $2}')

# extract the network prefix from the CGNAT address
net_cgnat_prefix=$(echo $ip_cgnat_addr | sed -e "s/^\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b$/\1.\2.\3./")
# extract the network index for the specified public IP from the CGNAT address
net_cgnat_index=$(echo $ip_cgnat_addr | sed -e "s/^\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b$/\3/")


ip_predef_min=$arg5
ip_predef_max=$arg6

# Checking if minimum and maximum IPs are predefined and doing what's necessary
if [ -n "$ip_predef_min" ] && [ -n "$ip_predef_max" ] ; then
    echo "Minimum and maximum IPs predefined"
    ip_cgnat_addr_min=$ip_predef_min
    ip_cgnat_addr_max=$ip_predef_max
    ip_num_min=$(echo $ip_cgnat_addr_min | sed -e "s/^\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b$/\4/")
    ip_num_max=$(echo $ip_cgnat_addr_max | sed -e "s/^\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b$/\4/")
    num_clients=$(echo ${ip_num_max}-${ip_num_min}+1 | bc)
else
    echo "Minimum and maximum IPs NOT predefined"
    # extracting maximum and minimum hosts
    ip_cgnat_addr_min=$(ipcalc $net_cgnat | grep -i "HostMin" | awk '{print $2}')
    ip_cgnat_addr_max=$(ipcalc $net_cgnat | grep -i "HostMax" | awk '{print $2}')
    ip_num_min=$(echo $ip_cgnat_addr_min | sed -e "s/^\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b$/\4/")
    ip_num_max=$(echo $ip_cgnat_addr_max | sed -e "s/^\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b.\b\([0-9]*\)\b$/\4/")
    # number of clients in CGNAT for specified network
    # num_clients="31"
    # num_clients=$(ipcalc $net_cgnat | grep -i "Hosts" | awk '{print $2}')
    num_clients=$(echo ${ip_num_max}-${ip_num_min}+1 | bc)
fi

ip_cgnat_addr_broadcast=$(ipcalc $net_cgnat | grep -i "Broadcast" | awk '{print $2}')


# Maximum number of ports to be allocated for clients of the specified network
#min_port="1"
min_port="$arg3"
#max_port="65537"
max_port="$arg4"

delta_port=$(echo ${max_port}-${min_port} | bc)

# Number of ports reserved for each client
#delta_port_per_client="2048"
delta_port_per_client=$(echo $delta_port/$num_clients | bc)

# If 1, write the rules; if not, only calculate to validate if there's any error in the number of ports per IP
write_on="1"
# Index of the CGNAT, usually defined by the 3rd octet of the IPv4 address
#cgnat_index="$net_cgnat_index"
cgnat_index="$argx"

# Defining directory/file names for configuration
file_name="cgnat_rules_${ip_cgnat_addr}.nft"
file_local="/etc/nftables/cgnat/"
file_local_and_name="${file_local}${file_name}"

echo "---------------------------------------"
echo "# PUBLIC IP: ${ip_wan_addr};"
echo "# CGNAT NETWORK IP: ${net_cgnat};"
echo "# Predefined Minimum Host IP: ${ip_predef_min};"
echo "# Predefined Maximum Host IP: ${ip_predef_max};"
echo "# Minimum Host IP: ${ip_cgnat_addr_min};"
echo "# Maximum Host IP: ${ip_cgnat_addr_max};"
echo "# Broadcast IP: ${ip_cgnat_addr_broadcast};"
echo "# Number of Hosts: $num_clients;"
echo "# Initial Port Number: $min_port;"
echo "# Final Port Number: $max_port;"
echo "# Number of Usable Ports: $delta_port;"
echo "# Number of Ports per Client: $delta_port_per_client;"
echo "---------------------------------------"

# Creating base directory
echo "CREATING BASE DIRECTORY"
mkdir -p $file_local

function create_rules() {
	# Creating initial base rules for nftables
	if [ $write_on -eq 1 ]; then
		echo "# ----- INDEX ${cgnat_index} -----"
		echo "# File created at: $current_time"
		echo ""
		echo "# PUBLIC IP: ${ip_wan_addr};"
		echo "# CGNAT NETWORK IP: ${net_cgnat};"
		echo "# Predefined Minimum Host IP: ${ip_predef_min};"
		echo "# Predefined Maximum Host IP: ${ip_predef_max};"
		echo "# Minimum Host IP: ${ip_cgnat_addr_min};"
		echo "# Maximum Host IP: ${ip_cgnat_addr_max};"
		echo "# Broadcast IP: ${ip_cgnat_addr_broadcast};"
		echo "# Number of Hosts: $num_clients;"
		echo "# Initial Port Number: $min_port;"
		echo "# Final Port Number: $max_port;"
		echo "# Number of Usable Ports: $delta_port;"
		echo "# Number of Ports per Client: $delta_port_per_client;"
		echo ""
		echo "define WAN_IP_ADDR_${cgnat_index} = $ip_wan_addr"
		echo "define NET_CGNAT_${cgnat_index} = $net_cgnat"
		echo "add chain ip cgnat CGNAT_OUT_${cgnat_index}"
		echo "add chain ip cgnat CGNAT_IN_${cgnat_index}"
		echo "flush chain ip cgnat CGNAT_OUT_${cgnat_index}"
		echo "flush chain ip cgnat CGNAT_IN_${cgnat_index}"
		echo "add rule ip cgnat CGNAT_IN ip daddr \$WAN_IP_ADDR_${cgnat_index} counter jump CGNAT_IN_${cgnat_index}"
		echo "add rule ip cgnat CGNAT_OUT ip saddr \$NET_CGNAT_${cgnat_index} counter jump CGNAT_OUT_${cgnat_index}"
		echo ""
	else
		echo "# calculating"
	fi

	for ((client=${ip_num_min}; client<=${ip_num_max}; client++)); do
		# Calculating ports
		if [ $client -eq ${ip_num_min} ] ; then
			#start_port="1"
			start_port="$min_port"
		else
			start_port=$(echo $end_port+1 | bc ;)
		fi;
		end_port=$(echo $start_port+$delta_port_per_client-1 | bc ;)
		# Checking maximum port
		if [ $end_port -gt $max_port ] ; then
			echo "# ERROR: Port limit exceeded ($max_port): $end_port"
			exit 1
		fi;
		# Creating nftables rules
		if [ $write_on -eq 1 ]; then
			echo "# CLIENT: ${net_cgnat_prefix}${client}; PORTS: ${start_port}-${end_port};"
			echo "add rule ip cgnat CGNAT_IN_$cgnat_index ip daddr \$WAN_IP_ADDR_${cgnat_index} tcp dport ${start_port}-${end_port} counter dnat to ${net_cgnat_prefix}${client}"
			echo "add rule ip cgnat CGNAT_IN_$cgnat_index ip daddr \$WAN_IP_ADDR_${cgnat_index} udp dport ${start_port}-${end_port} counter dnat to ${net_cgnat_prefix}${client}" 
			echo "add rule ip cgnat CGNAT_OUT_$cgnat_index ip protocol tcp ip saddr ${net_cgnat_prefix}${client} counter snat to \$WAN_IP_ADDR_${cgnat_index}:${start_port}-${end_port}"
			echo "add rule ip cgnat CGNAT_OUT_$cgnat_index ip protocol udp ip saddr ${net_cgnat_prefix}${client} counter snat to \$WAN_IP_ADDR_${cgnat_index}:${start_port}-${end_port}"
		else
			echo -n "."
		fi
	done;

	# Finalizing nftables rules
	if [ $write_on -eq 1 ]; then
		# ADD GRANULATED RULES
		echo "# everything that is not TCP or UDP"
		echo "add rule ip cgnat CGNAT_OUT_$cgnat_index counter snat to \$WAN_IP_ADDR_${cgnat_index}"
	fi
}

echo "CREATING RULES"
#create_rules
create_rules > ${file_local_and_name}

echo "CREATING FILE \"${file_local_and_name}\""
