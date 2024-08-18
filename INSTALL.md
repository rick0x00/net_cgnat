# Building CGNAT

Warning: This scenario is completely flexible and adaptable to the real scenario of your ISP.
Warning: When you implement your CGNAT this material may be out of date and problems may appear.

## CGNAT server/router (DEBIAN 12.6)

clone repository

```bash
    # clone repository
    git clone https://github.com/rick0x00/net_cgnat.git
    # change directory
    cd net_cgnat/box/generic/os/debian/native/nftables/
    # edit some variables
    vim build_cgant.sh
```

Edit variables

```bash
    # interface name of P2P/PTP
    # BORDER connection
    wan_interface_name="ens4"
    # BNG connection
    lan_interface_name="ens5"

    # IP Address of P2P/PTP
    # BORDER connection
    ip_wan_addr_ptp="172.16.1.2/30"
    ip_wan_gateway_ptp="172.16.1.1"
    # BNG connection
    ip_lan_addr_ptp="172.16.2.1/30"
    ip_lan_gateway_ptp="172.16.2.2"

    ### variables of CGNAT
    # IP Address to outside NAT(WAN)
    ip_wan_addr_1="200.200.200.2/24"
    # Network Address do inside NAT(LAN)
    # RFC 6598 (IANA-Reserved IPv4 Prefix for Shared Address Space)(100.64.0.0/10)
    net_cgnat_1="100.64.1.0/24"
```

Execute script

```bash
    #Execute the builder script
    bash build_cgant.sh
```

---

## more configs on GNS3 LAB

These settings are only useful in test scenarios, in a real environment use the appropriate settings.

### BORDER(VyOS 1.5-rolling-202408160021)

```bash
    #### WARNING: nat configuration is only needed in this LAB, it is not applicable in a real ISP, BGP for valid IPs network is a valid option
    set interfaces ethernet eth1 address 'dhcp'
    set interfaces ethernet eth2 address '172.16.1.1/30'
    set interfaces ethernet eth2 address '200.200.200.1/24'
    set nat source rule 200 outbound-interface name 'eth1'
    set nat source rule 200 source address '200.200.200.0/24'
    set nat source rule 200 translation address 'masquerade'
```

### BNG(VyOS 1.5-rolling-202408160021)

```bash
    #### WARNING: static route configuration is only needed in this LAB, it is not applicable in a real ISP, OSPF for valid IPs network is a valid option
    set interfaces ethernet eth1 address '172.16.2.2/30'
    set interfaces ethernet eth2 address '100.64.1.1/24'
    set protocols static route 0.0.0.0/0 next-hop 172.16.2.1
```
