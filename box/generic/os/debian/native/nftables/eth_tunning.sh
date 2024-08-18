#!/bin/bash


#### Rings/buffer RX and TX
### https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_and_managing_networking/increasing-the-ring-buffers-to-reduce-a-high-packet_drop_rate_configuring_and_managing_networking
#### NIC offloads
### https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/performance_tuning_guide/network-nic-offloads
#### txqueuelen (transmit queue) 
### https://www.cyberciti.biz/faq/change-txqueuelen/

# Capturing interface name
interface_name=$1

echo "Configuring tuning on network interface \"${interface_name}\"..."

### Checking how many cores/sockets are available
#cat /sys/devices/system/node/node0/cpulist

# Capturing CPU core list for CPU-affinity
#arg3=$3
#arg3=$(cat /sys/devices/system/node/node0/cpulist)
#num_cores=$(echo $arg3 | awk -F"-" '{print $2}')
#num_cores=$(echo "${num_cores}+1" | bc) 

# Configuring CPU-affinity
#ethtool -L ${interface_name} combined $num_cores
#bash /etc/nftables/scripts/set_irq_affinity.sh "${arg3}" ${interface_name}

# Adjusting RX and TX Rings/buffer to maximum supported (to reduce packet drops)
buffer_ring_rx_max=$(ethtool -g ${interface_name} | grep -i "RX:" | head -n 1)
buffer_ring_tx_max=$(ethtool -g ${interface_name} | grep -i "TX:" | head -n 1)
ethtool -G ${interface_name} rx ${buffer_ring_rx_max} tx ${buffer_ring_tx_max}

# Disabling TCP Segmentation Offload (TSO), Generic Receive Offload (GRO), and Generic Segmentation Offload (GSO)
ethtool -K ${interface_name} tso off gro off gso off

# txqueuelen (transmit queue)
ip link set ${interface_name} txqueuelen 10000
