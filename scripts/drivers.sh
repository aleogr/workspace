#!/bin/bash

apt install -y \
  firmware-misc-nonfree \
  nvidia-kernel-dkms

cat << EOF > /etc/modprobe.d/99-blacklist-nvidia-vfio.conf
blacklist nvidia
blacklist nouveau
EOF

#echo "vfio" >> /etc/initramfs-tools/modules
#echo "vfio_iommu_type1" >> /etc/initramfs-tools/modules
#echo "vfio_pci" >> /etc/initramfs-tools/modules
#echo "vfio_virqfd" >> /etc/initramfs-tools/modules

update-initramfs -u

systemctl restart libvirtd.service
