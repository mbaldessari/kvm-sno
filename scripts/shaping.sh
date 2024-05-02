#!/bin/bash
set -eux

# Goal on the kvm host is to let the VMs over br0 go at full speed (1Gbit/s) when they
# fetch data from the firewall itself and/or the internal networks
# Anything else (internet) goes at 100Mbit/s as to not clog the full bandwidth
INTERFACE=br0

RATE_LINE=1000mbit
RATE_FAST=1000mbit
RATE_SLOW=100mbit

tc qdisc del dev br0 root || /bin/true

# Setting r2q to 1514 to avoid the too low quantum warning
tc qdisc add dev ${INTERFACE} root handle 1: htb r2q 1514 default 40

tc class add dev ${INTERFACE} parent 1: classid 1:1 htb rate ${RATE_LINE}

tc class add dev ${INTERFACE} parent 1:1 classid 1:10 htb rate ${RATE_FAST}
tc class add dev ${INTERFACE} parent 1:1 classid 1:20 htb rate ${RATE_SLOW}

iptables -F OUTPUT
iptables -t mangle -F OUTPUT
# Testing rules with iperf instances running on fw
#iptables -t mangle -I OUTPUT -o ${INTERFACE} -p tcp -d 192.168.66.0/24 --dport 6000 -j CLASSIFY --set-class 1:10
#iptables -t mangle -I OUTPUT -o ${INTERFACE} -p tcp -d 192.168.66.0/24 --dport 6001 -j CLASSIFY --set-class 1:20
# Actual rules
iptables -t mangle -I OUTPUT -o ${INTERFACE} -d 192.168.66.0/24 -j CLASSIFY --set-class 1:10 
iptables -t mangle -I OUTPUT -o ${INTERFACE} -d 172.16.0.0/20 -j CLASSIFY --set-class 1:10
iptables -t mangle -I OUTPUT -o ${INTERFACE} -j CLASSIFY --set-class 1:20

iptables -nvL OUTPUT --line-numbers
iptables -t mangle -nvL OUTPUT --line-numbers
