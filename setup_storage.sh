#!/bin/bash
# =================================================================
# SCRIPT 1: PREPARAÇÃO DE INFRAESTRUTURA (RODAR UMA VEZ)
# =================================================================

# --- CONFIGURAÇÕES ---
# No VirtualBox: /dev/sdb (Geralmente)
# No PC Real: /dev/disk/by-id/nvme-WDS200T2X0E...
DISK_DEVICE="/dev/sdb" 

POOL_NAME="tank"
STORAGE_ID_VM="VM-Storage"
STORAGE_ID_BACKUP="Backup-Storage"

# --- SEGURANÇA ---
echo "!!! PERIGO: ISSO VAI FORMATAR O DISCO $DISK_DEVICE !!!"
echo "Pressione Enter para continuar ou Ctrl+C para cancelar."
read

# 1. Limpeza
echo "[1/5] Limpando disco..."
sgdisk --zap-all $DISK_DEVICE > /dev/null 2>&1
wipefs -a $DISK_DEVICE > /dev/null 2>&1

# 2. Criar Pool ZFS
echo "[2/5] Criando Pool ZFS '$POOL_NAME'..."
# NOTA: Para ativar criptografia no PC REAL, adicione estas flags na linha abaixo:
# -O encryption=aes-256-gcm -O keyformat=passphrase -O keylocation=prompt
zpool create -f -o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa $POOL_NAME $DISK_DEVICE

# 3. Criar Datasets (Pastas Lógicas)
echo "[3/5] Criando Datasets..."
zfs create $POOL_NAME/vms       # Para discos de VM
zfs create $POOL_NAME/backups   # Para arquivos de Backup

# 4. Adicionar Storage de VM (ZFS Nativo)
echo "[4/5] Configurando Storage de VMs..."
# --sparse 1 ativa o Thin Provisioning (economiza espaço)
pvesm add zfspool $STORAGE_ID_VM --pool $POOL_NAME/vms --content images,rootdir --sparse 1

# 5. Adicionar Storage de Backup (Diretório)
echo "[5/5] Configurando Storage de Backups..."
# --content define que aceita backups e ISOs
pvesm add dir $STORAGE_ID_BACKUP --path /$POOL_NAME/backups --content backup,iso,vztmpl

echo "✅ Infraestrutura pronta!"
