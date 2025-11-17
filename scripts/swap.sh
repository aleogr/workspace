#!/bin/bash

SWAP_FILE="/swap/swapfile"
SWAP_FILE_SIZE=64007

touch "$SWAP_FILE"
chmod 600 "$SWAP_FILE"
chattr +C "$SWAP_FILE"
dd if=/dev/zero of=/swap/swapfile bs=1M count=$SWAP_FILE_SIZE status=progress
mkswap "$SWAP_FILE"
swapon "$SWAP_FILE"
echo "$SWAP_FILE none swap defaults 0 0" >> /etc/fstab
