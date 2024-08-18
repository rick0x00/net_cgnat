#!/bin/bash


function config_kernel_modules(){

    echo "# enabling kernel modules"

    echo "# Responsible for network connection tracking.
    # Keeps a record of all active network connections on the system. This includes information about source, destination, protocol, ports...
    nf_conntrack

    # Provides support for address translation (NAT) for PPTP connections.
    #nf_conntrack_pptp

    # Performs NAT on H.323 connections used in video conferencing and real-time communications.
    #nf_conntrack_h323

    # Performs NAT for the SIP protocol, commonly used in VoIP calls.
    #nf_conntrack_sip

    # Performs NAT for connections related to the IRC protocol.
    #nf_conntrack_irc

    # Handles address translation (NAT) for FTP connections.
    #nf_conntrack_ftp

    # Supports address translation (NAT) for TFTP connections.
    #nf_conntrack_tftp
    " > /etc/modules-load.d/cgnat_modules.conf
    sed -i 's/^[[:space:]]\+//' /etc/modules-load.d/cgnat_modules.conf


    # listening enabled modules
    #lsmod | grep --color "bonding\|nf_conntrack\|nf_conntrack_pptp\|nf_conntrack_h323\|nf_conntrack_sip\|nf_conntrack_irc\|nf_conntrack_ftp\|nf_conntrack_tftp"
}

function config_kernel_timeout(){
    echo "Configuring kernel parameters to reduce timeout"

    ## configuring kernel parameters to try to reduce timeout
    # "The default TCP and UDP timeout values are too high for our CGNAT system - Marcelo Gondim"


    echo "
    # Configuration of timeouts for netfilter

    # Timeout for TCP SYN_SENT connections (sending a connection request)
    net.netfilter.nf_conntrack_tcp_timeout_syn_sent = 5

    # Timeout for TCP SYN_RECV connections (receiving a connection request)
    net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 5

    # Timeout for established TCP connections
    net.netfilter.nf_conntrack_tcp_timeout_established = 86400 # 24 hours

    # Timeout for TCP FIN_WAIT connections
    net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 10

    # Timeout for TCP CLOSE_WAIT connections
    net.netfilter.nf_conntrack_tcp_timeout_close_wait = 10

    # Timeout for TCP LAST_ACK connections
    net.netfilter.nf_conntrack_tcp_timeout_last_ack = 10

    # Timeout for TCP TIME_WAIT connections
    net.netfilter.nf_conntrack_tcp_timeout_time_wait = 10

    # Timeout for TCP CLOSE connections
    net.netfilter.nf_conntrack_tcp_timeout_close = 10

    # Maximum timeout for retransmissions of TCP connections
    net.netfilter.nf_conntrack_tcp_timeout_max_retrans = 300

    # Timeout for unacknowledged TCP connections
    net.netfilter.nf_conntrack_tcp_timeout_unacknowledged = 300

    # Timeout for UDP connections
    net.netfilter.nf_conntrack_udp_timeout = 10

    # Timeout for UDP connections in streaming mode
    net.netfilter.nf_conntrack_udp_timeout_stream = 180

    # Timeout for ICMP connections
    net.netfilter.nf_conntrack_icmp_timeout = 10

    # Timeout for generic connections
    net.netfilter.nf_conntrack_generic_timeout = 600
    " > /etc/sysctl.d/cgnat_reduce_timeout.conf
    sed -i 's/^[[:space:]]\+//' /etc/sysctl.d/cgnat_reduce_timeout.conf

    # Aplicar as configurações imediatamente sem reiniciar.
    sysctl -p /etc/sysctl.d/cgnat_reduce_timeout.conf >> /dev/null

}

function config_kernel_parameters(){

    echo "configuring kernel parameters"
    # This script configures kernel parameters

    # The above configurations improve memory usage, enable packet forwarding, and increase the system's maximum number of conntracks to 4096000.
    # If the conntrack overflows, your CGNAT will have problems and cause outages.

    # specify the location where the configurations will be stored

    echo "
    # Set the default network queuing discipline to 'fq'.
    # This can improve network performance, especially in high-load scenarios.
    net.core.default_qdisc=fq

    # Set the TCP congestion control algorithm to 'bbr'.
    # BBR (Bottleneck Bandwidth and Round-trip propagation time) is a congestion control algorithm aimed at improving network performance.
    net.ipv4.tcp_congestion_control=bbr

    # Set the maximum size of the packet receive buffer to a very high value.
    # This allows the system to receive large amounts of data in the buffer.
    net.core.rmem_max=2147483647

    # Set the maximum size of the packet send buffer to a very high value as well.
    net.core.wmem_max=2147483647

    # Configure the minimum, default, and maximum sizes of the TCP receive buffer.
    net.ipv4.tcp_rmem=4096 87380 2147483647

    # Configure the minimum, default, and maximum sizes of the TCP send buffer.
    net.ipv4.tcp_wmem=4096 65536 2147483647

    # Enable packet forwarding between network interfaces (turns the system into a router).
    net.ipv4.conf.all.forwarding=1

    # Set the number of buckets for the connection tracking table.
    # This can improve performance when there are many simultaneous connections.
    net.netfilter.nf_conntrack_buckets=512000

    # Set the maximum number of entries in the connection tracking table.
    net.netfilter.nf_conntrack_max=4096000

    # Set the system swapiness value to a low level (10).
    # This means the system will try to keep as much data as possible in physical memory before using swap memory.
    vm.swappiness=10
    " > /etc/sysctl.d/cgnat_parameters.conf
    sed -i 's/^[[:space:]]\+//' /etc/sysctl.d/cgnat_parameters.conf

    # Apply the configurations immediately without restarting.
    sysctl -p /etc/sysctl.d/cgnat_parameters.conf >> /dev/null

    # To check the number of conntracks in use:
    # echo "checking conntracks in use"
    # cat /proc/sys/net/netfilter/nf_conntrack_count
    # To list the conntracks:
    # cat /proc/net/nf_conntrack

}


config_kernel_modules
config_kernel_timeout
config_kernel_parameters