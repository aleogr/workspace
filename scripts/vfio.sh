#!/bin/bash

sed -i 's/^#*GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on vfio-pci.ids=10de:2203,10de:1aef"/' /etc/default/grub

update-grub

cat << EOF >> /etc/initramfs-tools/modules

# Módulos para VFIO Passthrough
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF

update-initramfs -u
