#!/bin/bash
# 06-install-pbs.sh
# Objetivo: Instalar PBS, Configurar Datastore e Linkar ao PVE (Localhost).

# --- CONFIGURAÇÕES ---
DATASTORE_NAME="Backup-PBS"
ZFS_PATH="/tank/backups"
PBS_USER="root@pam"
# ---------------------

set -e

echo ">>> [1/4] Instalando Proxmox Backup Server..."
apt install -y proxmox-backup-server proxmox-backup-client

echo ">>> [2/4] Configurando Permissões do ZFS..."
chown -R backup:backup $ZFS_PATH
chmod 700 $ZFS_PATH

echo ">>> [3/4] Criando Datastore no PBS..."
proxmox-backup-manager datastore create $DATASTORE_NAME $ZFS_PATH

echo ">>> [4/4] Conectando PVE ao PBS (Localhost)..."
FINGERPRINT=$(proxmox-backup-manager cert info | grep "Fingerprint" | awk '{print $NF}')

echo "Fingerprint detectado: $FINGERPRINT"

echo "Precisamos da senha do ROOT para conectar o PVE ao PBS:"
read -s PBS_PASSWORD

# 2. Adiciona o storage no PVE
# --server: localhost (127.0.0.1)
# --datastore: O nome que criamos acima
# --content: backup
pvesm add pbs "$DATASTORE_NAME" \
    --server 127.0.0.1 \
    --datastore "$DATASTORE_NAME" \
    --fingerprint "$FINGERPRINT" \
    --username "$PBS_USER" \
    --password "$PBS_PASSWORD" \
    --content backup

echo "✅ Proxmox Backup Server instalado e integrado!"
echo "Acesse o painel do PBS em: https://localhost:8007"
