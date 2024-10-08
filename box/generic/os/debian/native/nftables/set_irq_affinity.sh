#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2015 - 2019, Intel Corporation
#
# Affinitize interrupts to cores
#
# typical usage is (as root):
# set_irq_affinity -x local eth1 <eth2> <eth3>
# set_irq_affinity -s eth1
#
# to get help:
# set_irq_affinity

usage()
{
        echo
        echo "Usage: option -s <interface> to show current settings only"
        echo "Usage: $0 [-x|-X] [all|local|remote [<node>]|one <core>|custom|<cores>] <interface> ..."
        echo "  Options: "
        echo "    -s            Shows current affinity settings"
        echo "    -x            Configure XPS as well as smp_affinity"
        echo "    -X            Disable XPS but set smp_affinity"
        echo "    [all] is the default value"
        echo "    [remote [<node>]] can be followed by a specific node number"
        echo "  Examples:"
        echo "    $0 -s eth1            # Show settings on eth1"

        echo "    $0 all eth1 eth2      # eth1 and eth2 to all cores"
        echo "    $0 one 2 eth1         # eth1 to core 2 only"
        echo "    $0 local eth1         # eth1 to local cores only"
        echo "    $0 remote eth1        # eth1 to remote cores only"
        echo "    $0 custom eth1        # prompt for eth1 interface"
        echo "    $0 0-7,16-23 eth0     # eth1 to cores 0-7 and 16-23"
        echo
        exit 1
}

usageX()
{
        echo "options -x and -X cannot both be specified, pick one"
        exit 1
}

if [ "$1" == "-x" ]; then
        XPS_ENA=1
        shift
fi

if [ "$1" == "-s" ]; then
        SHOW=1
        echo Show affinity settings
        shift
fi

if [ "$1" == "-X" ]; then
        if [ -n "$XPS_ENA" ]; then
                usageX
        fi
        XPS_DIS=2
        shift
fi

if [ "$1" == -x ]; then
        usageX
fi

if [ -n "$XPS_ENA" ] && [ -n "$XPS_DIS" ]; then
        usageX
fi

if [ -z "$XPS_ENA" ]; then
        XPS_ENA=$XPS_DIS
fi

SED=`which sed`
if [[ ! -x $SED ]]; then
        echo " $0: ERROR: sed not found in path, this script requires sed"
        exit 1
fi

num='^[0-9]+$'

# search helpers
NOZEROCOMMA="s/^[0,]*//"
# Vars
AFF=$1
shift

case "$AFF" in
    remote)     [[ $1 =~ $num ]] && rnode=$1 && shift ;;
    one)        [[ $1 =~ $num ]] && cnt=$1 && shift ;;
    all)        ;;
    local)      ;;
    custom)     ;;
    [0-9]*)     ;;
    -h|--help)  usage ;;
    "")         usage ;;
    *)          IFACES=$AFF && AFF=all ;;       # Backwards compat mode
esac

# append the interfaces listed to the string with spaces
while [ "$#" -ne "0" ] ; do
        IFACES+=" $1"
        shift
done

# for now the user must specify interfaces
if [ -z "$IFACES" ]; then
        usage
        exit 2
fi

notfound()
{
        echo $MYIFACE: not found
        exit 15
}

# check the interfaces exist
for MYIFACE in $IFACES; do
        grep -q $MYIFACE /proc/net/dev || notfound
done

# support functions

build_mask()
{
        VEC=$core
        if [ $VEC -ge 32 ]
        then
                MASK_FILL=""
                MASK_ZERO="00000000"
                let "IDX = $VEC / 32"
                for ((i=1; i<=$IDX;i++))
                do
                        MASK_FILL="${MASK_FILL},${MASK_ZERO}"
                done

                let "VEC -= 32 * $IDX"
                MASK_TMP=$((1<<$VEC))
                MASK=$(printf "%X%s" $MASK_TMP $MASK_FILL)
        else
                MASK_TMP=$((1<<$VEC))
                MASK=$(printf "%X" $MASK_TMP)
        fi
}

show_affinity()
{
        # returns the MASK variable
        build_mask

        SMP_I=`sed -E "${NOZEROCOMMA}" /proc/irq/$IRQ/smp_affinity`
        HINT=`sed -E "${NOZEROCOMMA}" /proc/irq/$IRQ/affinity_hint`
        printf "ACTUAL  %s %d %s <- /proc/irq/$IRQ/smp_affinity\n" $IFACE $core $SMP_I
        printf "HINT    %s %d %s <- /proc/irq/$IRQ/affinity_hint\n" $IFACE $core $HINT
        IRQ_CHECK=`grep '[-,]' /proc/irq/$IRQ/smp_affinity_list`
        if [ ! -z $IRQ_CHECK ]; then
                printf " WARNING -- SMP_AFFINITY is assigned to multiple cores $IRQ_CHECK\n"
        fi
        if [ "$SMP_I" != "$HINT" ]; then
                printf " WARNING -- SMP_AFFINITY VALUE does not match AFFINITY_HINT \n"
        fi
        printf "NODE    %s %d %s <- /proc/irq/$IRQ/node\n" $IFACE $core `cat /proc/irq/$IRQ/node`
        printf "LIST    %s %d [%s] <- /proc/irq/$IRQ/smp_affinity_list\n" $IFACE $core `cat /proc/irq/$IRQ/smp_affinity_list`
        printf "XPS     %s %d %s <- /sys/class/net/%s/queues/tx-%d/xps_cpus\n" $IFACE $core `cat /sys/class/net/$IFACE/queues/tx-$((n-1))/xps_cpus` $IFACE $((n-1))
        if [ -z `ls /sys/class/net/$IFACE/queues/tx-$((n-1))/xps_rxqs` ]; then
                echo "WARNING: xps rxqs not supported on $IFACE"
        else
                printf "XPSRXQs %s %d %s <- /sys/class/net/%s/queues/tx-%d/xps_rxqs\n" $IFACE $core `cat /sys/class/net/$IFACE/queues/tx-$((n-1))/xps_rxqs` $IFACE $((n-1))
        fi
        printf "TX_MAX  %s %d %s <- /sys/class/net/%s/queues/tx-%d/tx_maxrate\n" $IFACE $core `cat /sys/class/net/$IFACE/queues/tx-$((n-1))/tx_maxrate` $IFACE $((n-1))
        printf "BQLIMIT %s %d %s <- /sys/class/net/%s/queues/tx-%d/byte_queue_limits/limit\n" $IFACE $core `cat /sys/class/net/$IFACE/queues/tx-$((n-1))/byte_queue_limits/limit` $IFACE $((n-1))
        printf "BQL_MAX %s %d %s <- /sys/class/net/%s/queues/tx-%d/byte_queue_limits/limit_max\n" $IFACE $core `cat /sys/class/net/$IFACE/queues/tx-$((n-1))/byte_queue_limits/limit_max` $IFACE $((n-1))
        printf "BQL_MIN %s %d %s <- /sys/class/net/%s/queues/tx-%d/byte_queue_limits/limit_min\n" $IFACE $core `cat /sys/class/net/$IFACE/queues/tx-$((n-1))/byte_queue_limits/limit_min` $IFACE $((n-1))
        if [ -z `ls /sys/class/net/$IFACE/queues/rx-$((n-1))/rps_flow_cnt` ]; then
                echo "WARNING: aRFS is not supported on $IFACE"
        else
                printf "RPSFCNT %s %d %s <- /sys/class/net/%s/queues/rx-%d/rps_flow_cnt\n" $IFACE $core `cat /sys/class/net/$IFACE/queues/rx-$((n-1))/rps_flow_cnt` $IFACE $((n-1))
        fi
        if [ -z `ls /sys/class/net/$IFACE/queues/rx-$((n-1))/rps_cpus` ]; then
                echo "WARNING: rps_cpus is not available on $IFACE"
        else
                printf "RPSCPU  %s %d %s <- /sys/class/net/%s/queues/rx-%d/rps_cpus\n" $IFACE $core `cat /sys/class/net/$IFACE/queues/rx-$((n-1))/rps_cpus` $IFACE $((n-1))
        fi
        echo
}

set_affinity()
{
        # returns the MASK variable
        build_mask

        printf "%s" $MASK > /proc/irq/$IRQ/smp_affinity
        printf "%s %d %s -> /proc/irq/$IRQ/smp_affinity\n" $IFACE $core $MASK
        SMP_I=`sed -E "${NOZEROCOMMA}" /proc/irq/$IRQ/smp_affinity`
        if [ "$SMP_I" != "$MASK" ]; then
                printf " ACTUAL\t%s %d %s <- /proc/irq/$IRQ/smp_affinity\n" $IFACE $core $SMP_I
                printf " WARNING -- SMP_AFFINITY setting failed\n"
        fi
        case "$XPS_ENA" in
        1)
                printf "%s %d %s -> /sys/class/net/%s/queues/tx-%d/xps_cpus\n" $IFACE $core $MASK $IFACE $((n-1))
                printf "%s" $MASK > /sys/class/net/$IFACE/queues/tx-$((n-1))/xps_cpus
        ;;
        2)
                MASK=0
                printf "%s %d %s -> /sys/class/net/%s/queues/tx-%d/xps_cpus\n" $IFACE $core $MASK $IFACE $((n-1))
                printf "%s" $MASK > /sys/class/net/$IFACE/queues/tx-$((n-1))/xps_cpus
        ;;
        *)
        esac
}

# Allow usage of , or -
#
parse_range () {
        RANGE=${@//,/ }
        RANGE=${RANGE//-/..}
        LIST=""
        for r in $RANGE; do
                # eval lets us use vars in {#..#} range
                [[ $r =~ '..' ]] && r="$(eval echo {$r})"
                LIST+=" $r"
        done
        echo $LIST
}

# Affinitize interrupts
#
doaff()
{
        CORES=$(parse_range $CORES)
        ncores=$(echo $CORES | wc -w)
        n=1

        # this script only supports interrupt vectors in pairs,
        # modification would be required to support a single Tx or Rx queue
        # per interrupt vector

        queues="${IFACE}-.*TxRx"

        irqs=$(grep "$queues" /proc/interrupts | cut -f1 -d:)
        [ -z "$irqs" ] && irqs=$(grep $IFACE /proc/interrupts | cut -f1 -d:)
        [ -z "$irqs" ] && irqs=$(for i in `ls -1 /sys/class/net/${IFACE}/device/msi_irqs | sort -n` ;do grep -w $i: /proc/interrupts | egrep -v 'fdir|async|misc|ctrl' | cut -f 1 -d :; done)
        [ -z "$irqs" ] && echo "Error: Could not find interrupts for $IFACE"

        if [ "$SHOW" == "1" ] ; then
                echo "TYPE IFACE CORE MASK -> FILE"
                echo "============================"
        else
                echo "IFACE CORE MASK -> FILE"
                echo "======================="
        fi

        for IRQ in $irqs; do
                [ "$n" -gt "$ncores" ] && n=1
                j=1
                # much faster than calling cut for each
                for i in $CORES; do
                        [ $((j++)) -ge $n ] && break
                done
                core=$i
                if [ "$SHOW" == "1" ] ; then
                        show_affinity
                else
                        set_affinity
                fi
                ((n++))
        done
}

# these next 2 lines would allow script to auto-determine interfaces
#[ -z "$IFACES" ] && IFACES=$(ls /sys/class/net)
#[ -z "$IFACES" ] && echo "Error: No interfaces up" && exit 1

# echo IFACES is $IFACES

CORES=$(</sys/devices/system/cpu/online)
[ "$CORES" ] || CORES=$(grep ^proc /proc/cpuinfo | cut -f2 -d:)

# Core list for each node from sysfs
node_dir=/sys/devices/system/node
for i in $(ls -d $node_dir/node*); do
        i=${i/*node/}
        corelist[$i]=$(<$node_dir/node${i}/cpulist)
done

for IFACE in $IFACES; do
        # echo $IFACE being modified

        dev_dir=/sys/class/net/$IFACE/device
        [ -e $dev_dir/numa_node ] && node=$(<$dev_dir/numa_node)
        [ "$node" ] && [ "$node" -gt 0 ] || node=0

        case "$AFF" in
        local)
                CORES=${corelist[$node]}
        ;;
        remote)
                [ "$rnode" ] || { [ $node -eq 0 ] && rnode=1 || rnode=0; }
                CORES=${corelist[$rnode]}
        ;;
        one)
                [ -n "$cnt" ] || cnt=0
                CORES=$cnt
        ;;
        all)
                CORES=$CORES
        ;;
        custom)
                echo -n "Input cores for $IFACE (ex. 0-7,15-23): "
                read CORES
        ;;
        [0-9]*)
                CORES=$AFF
        ;;
        *)
                usage
                exit 1
        ;;
        esac

        # call the worker function
        doaff
done

# check for irqbalance running
IRQBALANCE_ON=`ps ax | grep -v grep | grep -q irqbalance; echo $?`
if [ "$IRQBALANCE_ON" == "0" ] ; then
        echo " WARNING: irqbalance is running and will"
        echo "          likely override this script's affinitization."
        echo "          Please stop the irqbalance service and/or execute"
        echo "          'killall irqbalance'"
        exit 2
fi