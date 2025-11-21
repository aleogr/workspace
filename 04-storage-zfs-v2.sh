#!/bin/bash
# 04-storage-zfs-v2.sh
# Objetivo: Provisionar ZFS e Datasets (Sem adicionar VZDump).

# --- CONFIGURAÇÕES ---
DISK_DEVICE="/dev/disk/by-id/nvme-WD_BLACK_SN850X_2000GB_222503A00551"
#DISK_DEVICE="/dev/sdb"
POOL_NAME="tank"
STORAGE_ID_VM="VM-Storage"
ENABLE_ENCRYPTION="yes"
# ---------------------

set -e

# Cores
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")

header_info() {
    clear
    echo -e "${BL}
   __   __   ____  __   ___  ____
  / _\ (  ) (  __)/  \ / __)(  _ \
 /    \/ (_/\) _)(  O (( (_ \ )   /
 \_/\_/\____/(____)\__/ \___/(__\_)
    ${CL}"
    echo -e "${YW}Storage Provisioning: ZFS + Encryption${CL}"
    echo ""
}

header_info

echo -e "${RD}!!! ATENÇÃO: DISCO ALVO É $DISK_DEVICE !!!${CL}"
echo -e "${RD}Todos os dados serão perdidos.${CL}"
echo "Digite CONFIRMAR para formatar:"
read -r INPUT
if [ "$INPUT" != "CONFIRMAR" ]; then echo "Cancelado."; exit 1; fi

if [ ! -b "$DISK_DEVICE" ]; then echo "${RD}Erro: Disco não encontrado!${CL}"; exit 1; fi

echo -e "${GN}>>> [1/4] Limpando disco...${CL}"
sgdisk --zap-all "$DISK_DEVICE" > /dev/null
wipefs -a "$DISK_DEVICE" > /dev/null

echo -e "${GN}>>> [2/4] Criando Pool ZFS '$POOL_NAME'...${CL}"
ZPOOL_ARGS="-f -o ashift=12 -o autotrim=on -O compression=lz4 -O atime=off -O acltype=posixacl -O xattr=sa"

if [ "$ENABLE_ENCRYPTION" == "yes" ]; then
    echo -e "${YW}--> Criptografia ATIVADA. Defina a senha a seguir:${CL}"
    ZPOOL_ARGS="$ZPOOL_ARGS -O encryption=aes-256-gcm -O keyformat=passphrase -O keylocation=prompt"
fi

zpool create $ZPOOL_ARGS "$POOL_NAME" "$DISK_DEVICE"

echo -e "${GN}>>> [3/4] Criando Datasets...${CL}"
zfs create "$POOL_NAME/vms"
zfs create "$POOL_NAME/backups"

echo -e "${GN}>>> [4/4] Registrando Storage de VMs...${CL}"
pvesm add zfspool "$STORAGE_ID_VM" --pool "$POOL_NAME/vms" --content images,rootdir --sparse 1

echo -e "${GN}✅ Storage ZFS Configurado!${CL}"
