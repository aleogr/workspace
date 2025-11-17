#!/bin/bash

apt install \
	qemu-kvm \
	qemu-system-x86 \
	qemu-system-arm \
	qemu-system-aarch64 \
	qemu-system-mips \
	qemu-system-ppc \
	qemu-system-s390x \
	qemu-system-riscv \
	qemu-system-alpha \
	qemu-system-sparc \
	qemu-system-m68k \
	qemu-user \
	qemu-guest-agent \
	qemu-utils \
	libvirt-daemon-system \
	libvirt-clients \
	bridge-utils \
	virt-manager \
	ovmf

usermod -aG kvm,libvirt aleogr
systemctl enable --now libvirtd

touch /var/log/libvirt-hook.log
cp -r hooks /etc/libvirt/

exit 0
