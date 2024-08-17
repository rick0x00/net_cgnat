#!/bin/bash


#### Rings/buffer RX e TX
### https://access.redhat.com/documentation/pt-br/red_hat_enterprise_linux/9/html/configuring_and_managing_networking/increasing-the-ring-buffers-to-reduce-a-high-packet-drop-rate_configuring-and-managing-networking
#### NIC offloads
### https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/performance_tuning_guide/network-nic-offloads
#### txqueuelen (transmit queue) 
### https://www.cyberciti.biz/faq/change-txqueuelen/

# capturando nome de interface
interface_name=$1

echo "configurando tunnig na interface de rede \"${interface_name}\"..."

### verificando quantos cores / socket tem disponivel
#cat /sys/devices/system/node/node0/cpulist

# capturando sequencia de cores de CPU para CPU-affinity
#arg3=$3
#arg3=$(cat /sys/devices/system/node/node0/cpulist)
#num_cores=$(echo $arg3 | awk -F"-" '{print $2}')
#num_cores=$(echo "${num_cores}+1" | bc) 

# configurando CPU-affinity
#ethtool -L ${interface_name} combined $num_cores
#bash /etc/nftables/scripts/set_irq_affinity.sh "${arg3}" ${interface_name}

# ajustando os Rings/buffer RX e TX para o maximo suportado(para reduzir descarte de pacotes)
buffer_ring_rx_max=$(ethtool -g ${interface_name} | grep -i "RX:" | head -n 1)
buffer_ring_tx_max=$(ethtool -g ${interface_name} | grep -i "TX:" | head -n 1)
ethtool -G ${interface_name} rx ${buffer_ring_rx_max} tx ${buffer_ring_tx_max}

# desabilitando TCP Segmentation Offload (TSO), Generic Receive Offload (GRO) e Generic Segmentation Offload (GSO)
ethtool -K ${interface_name} tso off gro off gso off

# txqueuelen (transmit queue)
ip link set ${interface_name} txqueuelen 10000
