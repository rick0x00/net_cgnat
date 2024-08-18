#!/bin/bash
echo "Configuring CGNAT..."

hora_agora=$(date --iso-8601="s")

file_local_base="/etc/nftables/"
file_local_cgnat="/etc/nftables/cgnat/"
file_local_cgnat_bkp="/etc/nftables/cgnat_bkp/"


echo "------------------------------------------------------------------"
echo "Making BACKUP..."

echo "making 'log' of end of life rules..."
echo "Configs Cleaned at: ${hora_agora} 
used since './usage_date_start.log'" > ${file_local_cgnat}/usage_date_end.log

echo "making backup directory ${file_local_cgnat_bkp}${hora_agora}"
mkdir -p ${file_local_base}
mkdir -p ${file_local_cgnat}
mkdir -p ${file_local_cgnat_bkp}${hora_agora}
mkdir -p ${file_local_cgnat_bkp}${hora_agora}/etc/network/interfaces/

echo "copy files to backup"
cp ${file_local_cgnat}* ${file_local_cgnat_bkp}${hora_agora}/
cp /etc/nftables.conf ${file_local_cgnat_bkp}${hora_agora}/etc/
cp /etc/network/interfaces ${file_local_cgnat_bkp}${hora_agora}/etc/network/interfaces/

echo "cleaning existent rules"
rm -f ${file_local_cgnat}*

echo "------------------------------------------------------------------"
echo "making 'log' of start of life rules..."
echo "Configs maked at: ${hora_agora}
used until'./usage_date_end.log'" > ${file_local_cgnat}/usage_date_start.log

echo "Configuring networks..."

# bash /etc/nftables/scripts/create_cgnat_networks_rules.sh "indice" "public_ip" "private_cgnat_network" "start_port" "end_port" "start_ip" "end_ip"
# bash /etc/nftables/scripts/create_cgnat_networks_rules.sh "2" "200.200.200.2/24" "100.64.1.0/24" "1" "65535" "100.64.1.1" "100.64.1.20"
