#!/bin/bash
# =================================================================
# 03-storage-zfs.sh
# Objetivo: Provisionar disco secundário com ZFS, Datasets e Criptografia opcional.
# =================================================================

# --- VARIÁVEIS DE CONFIGURAÇÃO (EDITE AQUI) ---

# No VirtualBox: "/dev/sdb"
# No PC Real: "/dev/disk/by-id/nvme-WDS200T2X0E-..." (Use ID único!)
DISK_DEVICE="/dev/sdb"

POOL_NAME="tank"
STORAGE_ID_VM="VM-Storage"
STORAGE_ID_BACKUP="Backup-Storage"

# Ativar criptografia? ("yes" ou "no")
# Se "yes", ele pedirá a senha durante a execução.
ENABLE_ENCRYPTION="no"

# ----------------------------------------------

set -e

# --- VERIFICAÇÃO DE SEGURANÇA ---
echo "======================================================="
echo "!!! PERIGO EXTREMO: DESTRUIÇÃO DE DADOS !!!"
echo "======================================================="
echo "Dispositivo alvo: $DISK_DEVICE"
echo "-------------------------------------------------------"
echo "Para continuar, digite: CONFIRMAR"
read -r INPUT

if [ "$INPUT" != "CONFIRMAR" ]; then
    echo "Operação cancelada pelo usuário."
    exit 1
fi

# Verifica se o disco existe
if [ ! -b "$DISK_DEVICE" ]; then
    echo "ERRO: O dispositivo $DISK_DEVICE não foi encontrado!"
    exit 1
fi

echo ">>> [1/5] Limpando tabelas de partição antigas..."
# Redireciona saída para null para limpar a tela, mas mostra erros se houver
sgdisk --zap-all "$DISK_DEVICE" > /dev/null
wipefs -a "$DISK_DEVICE" > /dev/null
echo "[OK] Disco limpo."

echo ">>> [2/5] Criando Pool ZFS '$POOL_NAME'..."

# Monta os argumentos base
# ashift=12 (4k sectors) | compression=lz4 (Speed) | atime=off (Performance/SSD Life)
ZPOOL_ARGS="-f -o ashift=12 -O compression=lz4 -O atime=off -O acltype=posixacl -O xattr=sa"

# Adiciona argumentos de criptografia se solicitado
if [ "$ENABLE_ENCRYPTION" == "yes" ]; then
    echo "--> Criptografia ATIVADA. Prepare-se para definir a senha."
    ZPOOL_ARGS="$ZPOOL_ARGS -O encryption=aes-256-gcm -O keyformat=passphrase -O keylocation=prompt"
fi

# Executa a criação
zpool create $ZPOOL_ARGS "$POOL_NAME" "$DISK_DEVICE"
echo "[OK] Pool criado."

echo ">>> [3/5] Criando Datasets (Pastas Lógicas)..."
zfs create "$POOL_NAME/vms"
zfs create "$POOL_NAME/backups"
echo "[OK] Datasets criados."

echo ">>> [4/5] Configurando Storage de VMs (Proxmox)..."
# sparse=1 ativa Thin Provisioning
pvesm add zfspool "$STORAGE_ID_VM" --pool "$POOL_NAME/vms" --content images,rootdir --sparse 1
echo "[OK] Storage de VMs registrado."

echo ">>> [5/5] Configurando Storage de Backups (Proxmox)..."
pvesm add dir "$STORAGE_ID_BACKUP" --path "/$POOL_NAME/backups" --content backup,iso,vztmpl
echo "[OK] Storage de Backups registrado."

echo "✅ Configuração de Storage Concluída!"
