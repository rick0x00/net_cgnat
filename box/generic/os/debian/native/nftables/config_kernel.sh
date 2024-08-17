#!/bin/bash


function config_kernel_modules(){
    #configura modulos do kernel que serao carregados automaticamente no boot do sistema

    echo "habilitando modulos de kernel"

echo "
# Responsavel pelo rastreamento de conexoes de rede.
# mantem um registro de todas as conexões de rede ativas no sistema. Isso inclui informacoes sobre a origem, destino, protocolo, portas...
nf_conntrack

#Oferece suporte à tradução de enderecos (NAT) para conexões PPTP.
nf_nat_pptp

#Realiza NAT em conexões H.323 usadas em videoconferencias e comunicacoes em tempo real.
nf_nat_h323

#Realiza NAT para o protocolo SIP, comumente usado em chamadas VoIP.
nf_nat_sip

#Realiza NAT para conexões relacionadas ao protocolo IRC.
nf_nat_irc

#Lida com a traducao de enderecos (NAT) para conexoes FTP.
nf_nat_ftp

#Suporta a traducao de enderecos (NAT) para conexoes TFTP.
nf_nat_tftp
" > /etc/modules-load.d/cgnat_modules.conf


    # listando modulos ativos
    #lsmod | grep --color "bonding\|nf_conntrack\|nf_nat_pptp\|nf_nat_h323\|nf_nat_sip\|nf_nat_irc\|nf_nat_ftp\|nf_nat_tftp"
}


function config_kernel_timeout(){
    echo "Configurando parametros de kernel para reduzir timeout"

    ## configurando parametros do kernel para tentar reduzir timeout
    #"Os tempos padroes dos timeouts de tcp e udp sao altos para o nosso sistema de CGNAT - Marcelo Gondim"

echo "
# Configuração dos timeouts para o netfilter

# Timeout para conexões TCP SYN_SENT (enviando um pedido de conexão)
net.netfilter.nf_conntrack_tcp_timeout_syn_sent = 5

# Timeout para conexões TCP SYN_RECV (recebendo um pedido de conexão)
net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 5

# Timeout para conexões TCP estabelecidas
net.netfilter.nf_conntrack_tcp_timeout_established = 86400 # 24 horas

# Timeout para conexões TCP FIN_WAIT
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 10

# Timeout para conexões TCP CLOSE_WAIT
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 10

# Timeout para conexões TCP LAST_ACK
net.netfilter.nf_conntrack_tcp_timeout_last_ack = 10

# Timeout para conexões TCP TIME_WAIT
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 10

# Timeout para conexões TCP CLOSE
net.netfilter.nf_conntrack_tcp_timeout_close = 10

# Timeout máximo para retransmissões de conexões TCP
net.netfilter.nf_conntrack_tcp_timeout_max_retrans = 300

# Timeout para conexões TCP não reconhecidas
net.netfilter.nf_conntrack_tcp_timeout_unacknowledged = 300

# Timeout para conexões UDP
net.netfilter.nf_conntrack_udp_timeout = 10

# Timeout para conexões UDP em modo streaming
net.netfilter.nf_conntrack_udp_timeout_stream = 180

# Timeout para conexões ICMP
net.netfilter.nf_conntrack_icmp_timeout = 10

# Timeout para conexões genéricas
net.netfilter.nf_conntrack_generic_timeout = 600
" > /etc/sysctl.d/cgnat_reduce_timeout.conf

    # Aplicar as configurações imediatamente sem reiniciar.
    sysctl -p /etc/sysctl.d/cgnat_reduce_timeout.conf >> /dev/null

}

function config_kernel_parameters(){

    echo "configurando parametros do kernel"
    # Este script configura parametros  do kernel

    # As configuracoes acima melhoram o uso de memoria, habilita o encaminhamento dos pacotes e aumenta a quantidade maxima de conntracks do sistema para 4096000.
    # Se o conntrack estourar, seu CGNAT tera problemas e causara indisponibilidades.

    # define local onde estara as configuracoes

echo "
# Definir algoritmo de escalonamento padrão da rede para 'fq'.
# Isso pode melhorar o desempenho da rede, especialmente em cenarios de alta carga.
net.core.default_qdisc=fq

# Definir o algoritmo de controle de congestionamento TCP como 'bbr'.
# O BBR (Bottleneck Bandwidth and Round-trip propagation time) e um algoritmo de controle de congestionamento que visa melhorar o desempenho da rede.
net.ipv4.tcp_congestion_control=bbr

# Definir o tamanho maximo do buffer de recepcao de pacotes para um valor muito alto.
# o que permite que o sistema receba grandes quantidades de dados em buffer
net.core.rmem_max=2147483647

# Definir o tamanho maximo do buffer de envio de pacotes tambem para um valor muito alto.
net.core.wmem_max=2147483647

# Configurar os tamanhos minimo, padrão e maximo do buffer de recepcao TCP.
net.ipv4.tcp_rmem=4096 87380 2147483647

# Configurar os tamanhos minimo, padrao e maximo do buffer de envio TCP.
net.ipv4.tcp_wmem=4096 65536 2147483647

# Ativar o encaminhamento de pacotes entre interfaces de rede (transforma o sistema em um roteador).
net.ipv4.conf.all.forwarding=1

# Ativar a ajuda de rastreamento de conexao de rede
# util para protocolos que necessitam de assistencia no rastreamento de conexoes, como o FTP, SIP...
net.netfilter.nf_conntrack_helper=1

# Definir o numero de buckets (compartimentos) para a tabela de rastreamento de conexao.
# Isso pode melhorar o desempenho quando ha muitas conexões simultaneas
net.netfilter.nf_conntrack_buckets=512000

# Definir o numero maximo de entradas na tabela de rastreamento de conexao.
net.netfilter.nf_conntrack_max=4096000

# Definir a politica de troca do sistema para um valor baixo (10).
# significa que o sistema tentara manter o maximo de dados na memoria fisica antes de usar a memoria de troca.
vm.swappiness=10
" > /etc/sysctl.d/cgnat_parameters.conf

    # Aplicar as configurações imediatamente sem reiniciar.
    sysctl -p /etc/sysctl.d/cgnat_parameters.conf >> /dev/null


    # Para consultar a quantidade de conntracks em uso:
    #echo "verificando contraks em uso"
    #cat /proc/sys/net/netfilter/nf_conntrack_count
    # Para listar as conntracks:
    #cat /proc/net/nf_conntrack
}


config_kernel_modules
config_kernel_timeout
config_kernel_parameters