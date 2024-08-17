#!/bin/bash
echo "CONFIGURANDO CGNAT...."

## guardando a hora
hora_agora=$(date --iso-8601="s")

file_local_base="/etc/nftables/"
file_local_cgnat="/etc/nftables/cgnat/"
file_local_cgnat_bkp="/etc/nftables/cgnat_bkp/"


echo "------------------------------------------------------------------"
echo "FAZENDO BACKUP..."

echo "criando 'registro' de data de FIM do uso da regras aplicadas"
echo "configuracoes APAGADAS em: ${hora_agora} com uso desde a data descrita em './usage_date_start.log'" > ${file_local_cgnat}/usage_date_end.log

echo "criando diretorio de backup ${file_local_cgnat_bkp}${hora_agora}"
mkdir -p ${file_local_base}
mkdir -p ${file_local_cgnat}
mkdir -p ${file_local_cgnat_bkp}${hora_agora}
mkdir -p ${file_local_cgnat_bkp}${hora_agora}/etc/network/interfaces/

echo "copiando arquivos para o backup"
cp ${file_local_cgnat}* ${file_local_cgnat_bkp}${hora_agora}/
cp /etc/nftables.conf ${file_local_cgnat_bkp}${hora_agora}/etc/
cp /etc/network/interfaces ${file_local_cgnat_bkp}${hora_agora}/etc/network/interfaces/

echo "apagando arquivos existentes"
rm -f ${file_local_cgnat}*

echo "------------------------------------------------------------------"
echo "criando 'registro' de data de INICIO do uso da regras aplicadas"
echo "configuracoes CRIADAS em: ${hora_agora} e em uso ate a data descrita em './usage_date_end.log'" > ${file_local_cgnat}/usage_date_start.log

echo "CONFIGURANDO REDES..."


# bash /etc/nftables/scripts/create_cgnat_networks_rules.sh "indice" "public_ip" "private_cgnat_network" "start_port" "end_port" "start_ip" "end_ip"
# bash /etc/nftables/scripts/create_cgnat_networks_rules.sh "2" "200.200.200.2/24" "100.64.1.0/24" "1" "65535" "100.64.1.1" "100.64.1.20"
