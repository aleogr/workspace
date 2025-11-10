#!/bin/sh

DEV_EFI="/dev/nvme0n1p1"
DEV_BOOT="/dev/nvme0n1p2"
DEV_CRYPT="/dev/mapper/nvme0n1p3_crypt"

umount "$DEV_EFI"
umount "$DEV_BOOT"
umount "$DEV_CRYPT"

mount "$DEV_CRYPT" /mnt/

cd /mnt
mv @rootfs/ @

btrfs su cr @root
btrfs su cr @home
btrfs su cr @tmp
btrfs su cr @log
btrfs su cr @cache
btrfs su cr @vms
btrfs su cr @swap
btrfs su cr @.snapshots

mount -o noatime,compress=zstd,subvol=@ "$DEV_CRYPT" /target

mkdir -p /target/boot/efi/
mkdir -p /target/root
mkdir -p /target/home
mkdir -p /target/tmp
mkdir -p /target/var/log
mkdir -p /target/var/cache
mkdir -p /target/var/lib/libvirt/qcow2
mkdir -p /target/swap
mkdir -p /target/.snapshots

mount -o noatime,compress=zstd,subvol=@root "$DEV_CRYPT" /target/root
mount -o noatime,compress=zstd,subvol=@home "$DEV_CRYPT" /target/home
mount -o noatime,compress=zstd,subvol=@tmp "$DEV_CRYPT" /target/tmp
mount -o noatime,compress=zstd,subvol=@log "$DEV_CRYPT" /target/var/log
mount -o noatime,compress=zstd,subvol=@cache "$DEV_CRYPT" /target/var/cache
mount -o noatime,compress=zstd,subvol=@vms "$DEV_CRYPT" /target/var/lib/libvirt/qcow2
mount -o noatime,nodatacow,subvol=@swap "$DEV_CRYPT" /target/swap
mount -o noatime,compress=zstd,subvol=@.snapshots "$DEV_CRYPT" /target/.snapshots

mount "$DEV_BOOT" /target/boot/
mount "$DEV_EFI" /target/boot/efi/

FSTAB_PATH="/target/etc/fstab"

UUID_EFI=$(blkid -s UUID -o value "$DEV_EFI")
UUID_BOOT=$(blkid -s UUID -o value "$DEV_BOOT")
UUID_BTRFS=$(blkid -s UUID -o value "$DEV_CRYPT")

# Cabeçalho do arquivo
cat << EOF > "$FSTAB_PATH"
# /etc/fstab: static file system information.
EOF

echo "UUID=$UUID_EFI /boot/efi vfat umask=0077 0 1" >> "$FSTAB_PATH"
echo "UUID=$UUID_BOOT /boot ext4 defaults 0 2" >> "$FSTAB_PATH"

BTRFS_DEV="UUID=$UUID_BTRFS"
BTRFS_OPTS="noatime,compress=zstd"
BTRFS_SWAP_OPTS="noatime,nodatacow"

echo "$BTRFS_DEV / btrfs $BTRFS_OPTS,subvol=@ 0 0" >> "$FSTAB_PATH"
echo "$BTRFS_DEV /root btrfs $BTRFS_OPTS,subvol=@root 0 0" >> "$FSTAB_PATH"
echo "$BTRFS_DEV /home btrfs $BTRFS_OPTS,subvol=@home 0 0" >> "$FSTAB_PATH"
echo "$BTRFS_DEV /tmp btrfs $BTRFS_OPTS,subvol=@tmp 0 0" >> "$FSTAB_PATH"
echo "$BTRFS_DEV /var/log btrfs $BTRFS_OPTS,subvol=@log 0 0" >> "$FSTAB_PATH"
echo "$BTRFS_DEV /var/cache btrfs $BTRFS_OPTS,subvol=@cache 0 0" >> "$FSTAB_PATH"
echo "$BTRFS_DEV /var/lib/libvirt/qcow2 btrfs $BTRFS_OPTS,subvol=@vms 0 0" >> "$FSTAB_PATH"
echo "$BTRFS_DEV /swap btrfs $BTRFS_SWAP_OPTS,subvol=@swap 0 0" >> "$FSTAB_PATH"
echo "$BTRFS_DEV /.snapshots btrfs $BTRFS_OPTS,subvol=@.snapshots 0 0" >> "$FSTAB_PATH"

echo "/dev/sr0 /media/cdrom0 udf,iso9660 user,noauto 0 0" >> "$FSTAB_PATH"