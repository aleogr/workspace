#!/bin/bash
# 04-storage-zfs.sh
# Objetivo: Provisionar ZFS e Datasets (Sem adicionar VZDump).

# --- CONFIGURAÇÕES ---
DISK_DEVICE="/dev/sdb" # No seu PC real será o ID: /dev/disk/by-id/nvme-WDS...
POOL_NAME="tank"
STORAGE_ID_VM="VM-Storage"
ENABLE_ENCRYPTION="yes"

set -e

echo "!!! ATENÇÃO: DISCO ALVO É $DISK_DEVICE !!!"
echo "Digite CONFIRMAR para formatar:"
read -r INPUT
if [ "$INPUT" != "CONFIRMAR" ]; then echo "Cancelado."; exit 1; fi

if [ ! -b "$DISK_DEVICE" ]; then echo "Disco não encontrado!"; exit 1; fi

echo ">>> [1/4] Limpando disco..."
sgdisk --zap-all "$DISK_DEVICE" > /dev/null
wipefs -a "$DISK_DEVICE" > /dev/null

echo ">>> [2/4] Criando Pool ZFS '$POOL_NAME'..."
ZPOOL_ARGS="-f -o ashift=12 -O compression=lz4 -O atime=off -O autotrim=on -O acltype=posixacl -O xattr=sa"

if [ "$ENABLE_ENCRYPTION" == "yes" ]; then
    echo "--> Criptografia ATIVADA. Defina a senha:"
    ZPOOL_ARGS="$ZPOOL_ARGS -O encryption=aes-256-gcm -O keyformat=passphrase -O keylocation=prompt"
fi

zpool create $ZPOOL_ARGS "$POOL_NAME" "$DISK_DEVICE"

echo ">>> [3/4] Criando Datasets..."
zfs create "$POOL_NAME/vms"
zfs create "$POOL_NAME/backups" 

echo ">>> [4/4] Registrando Storage de VMs..."
pvesm add zfspool "$STORAGE_ID_VM" --pool "$POOL_NAME/vms" --content images,rootdir --sparse 1

echo "✅ Storage ZFS Configurado!"
