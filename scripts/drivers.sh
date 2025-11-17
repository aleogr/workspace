#!/bin/bash

apt install -y \
  firmware-misc-nonfree \
  nvidia-kernel-dkms

cat << EOF > /etc/modprobe.d/99-blacklist-nvidia-vfio.conf
blacklist nvidia
blacklist nouveau
EOF

update-initramfs -u

systemctl restart libvirtd.service
