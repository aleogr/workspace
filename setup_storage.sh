#!/bin/bash

# ==============================================================================
# SCRIPT DE PROVISIONAMENTO DE STORAGE ZFS PROXMOX
# ==============================================================================
# Este script automatiza:
# 1. Criação do Pool ZFS (zpool)
# 2. Criação dos Datasets (vms e backups)
# 3. Cadastro dos Storages no Proxmox (pvesm)
# ==============================================================================

# --- CONFIGURAÇÕES (EDITE AQUI) ---

# No VirtualBox geralmente é /dev/sdb.
# No seu PC real será o ID: /dev/disk/by-id/nvme-WDS...
DISK_DEVICE="/dev/sdb"  

POOL_NAME="tank"
DATASET_VMS="vms"
DATASET_BACKUP="backups"

# Nomes que aparecerão na Interface Web do Proxmox
ID_STORAGE_VM="vm-storage"
ID_STORAGE_BACKUP="backup-storage"

# --- INÍCIO DO SCRIPT ---

echo "!!! ATENÇÃO !!!"
echo "Este script irá FORMATAR e DESTRUIR todos os dados em: $DISK_DEVICE"
echo "Você tem 5 segundos para cancelar (Ctrl+C)..."
sleep 5

echo "=== 1. LIMPANDO O DISCO ==="
# Remove tabelas de partição antigas para evitar erros de "disk busy"
sgdisk --zap-all $DISK_DEVICE
wipefs -a $DISK_DEVICE
echo "-> Disco limpo."

echo "=== 2. CRIANDO O POOL ZFS ('$POOL_NAME') ==="
# -f: Força a criação
# ashift=12: Otimização para SSD/NVMe (4k)
# compression=lz4: Compressão ativa no pool todo
# acltype=posixacl: Boa prática para permissões Linux
zpool create -f -o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa $POOL_NAME $DISK_DEVICE
echo "-> Pool '$POOL_NAME' criado."

echo "=== 3. CRIANDO OS DATASETS (DIVISÕES LÓGICAS) ==="
# Dataset para discos de VM
zfs create $POOL_NAME/$DATASET_VMS
echo "-> Dataset '$POOL_NAME/$DATASET_VMS' criado."

# Dataset para arquivos de Backup
zfs create $POOL_NAME/$DATASET_BACKUP
echo "-> Dataset '$POOL_NAME/$DATASET_BACKUP' criado."

echo "=== 4. REGISTRANDO STORAGE DE VMs NO PROXMOX ==="
# pvesm add zfspool: Adiciona storage tipo ZFS
# --pool: Aponta para o dataset específico
# --content: Define que aceita imagens de disco e containers
# --sparse 1: Ativa Thin Provisioning
pvesm add zfspool $ID_STORAGE_VM --pool $POOL_NAME/$DATASET_VMS --content images,rootdir --sparse 1
echo "-> Storage '$ID_STORAGE_VM' registrado."

echo "=== 5. REGISTRANDO STORAGE DE BACKUP NO PROXMOX ==="
# pvesm add dir: Adiciona storage tipo Diretório
# --path: Aponta para onde o ZFS montou o dataset (padrão é /nome_do_pool/nome_dataset)
# --content: Define que aceita backups, ISOs e templates
pvesm add dir $ID_STORAGE_BACKUP --path /$POOL_NAME/$DATASET_BACKUP --content backup,iso,vztmpl
echo "-> Storage '$ID_STORAGE_BACKUP' registrado."

echo "=================================================="
echo "       INSTALAÇÃO CONCLUÍDA COM SUCESSO"
echo "=================================================="
echo "Verifique no menu lateral da interface web."
