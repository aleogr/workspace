#!/bin/bash

apt install \
	network-manager \
	network-manager-gnome
systemctl disable networking
systemctl stop networking
rm -f /etc/network/interfaces
systemctl enable NetworkManager

nmcli con add type bridge con-name vlan-vm.bridge ifname vlan-vm.bridge stp no
nmcli con add type vlan con-name eno2.vlan-vm dev eno2 id 6 master vlan-vm.bridge
nmcli con up vlan-vm.bridge
nmcli con up eno2.vlan-vm
cd /etc/libvirt/qemu/networks
echo "<network>" > "vlan-vm.bridge.xml"
echo "<name>vlan-vm.bridge</name>" >> "vlan-vm.bridge.xml"
echo "<forward mode='bridge'/>" >> "vlan-vm.bridge.xml"
echo "<bridge name='vlan-vm.bridge'/>" >> "vlan-vm.bridge.xml"
echo "</network>" >> "vlan-vm.bridge.xml"
virsh net-define vlan-vm.bridge.xml
virsh net-autostart vlan-vm.bridge
virsh net-start vlan-vm.bridge