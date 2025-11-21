#!/bin/bash
# 06-install-pbs-v2.sh
# Objetivo: Instalar PBS, Configurar Datastore e Linkar ao PVE (Localhost).

# --- CONFIGURAÇÕES ---
DATASTORE_NAME="Backup-PBS"
ZFS_PATH="/tank/backups"
PBS_USER="root@pam"
# ---------------------

set -e

# Cores
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
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
    echo -e "${YW}Proxmox Backup Server: Local Integration${CL}"
    echo ""
}

header_info

echo -e "${GN}>>> [1/4] Instalando Proxmox Backup Server...${CL}"
apt install -y proxmox-backup-server proxmox-backup-client

echo -e "${GN}>>> [2/4] Configurando Permissões do ZFS ($ZFS_PATH)...${CL}"
chown -R backup:backup $ZFS_PATH
chmod 700 $ZFS_PATH

echo -e "${GN}>>> [3/4] Criando Datastore no PBS...${CL}"
if proxmox-backup-manager datastore list | grep -q "$DATASTORE_NAME"; then
    echo "Datastore '$DATASTORE_NAME' já existe."
else
    proxmox-backup-manager datastore create $DATASTORE_NAME $ZFS_PATH
    echo "[OK] Datastore criado."
fi

echo -e "${GN}>>> [4/4] Conectando PVE ao PBS (Localhost)...${CL}"

FINGERPRINT=$(proxmox-backup-manager cert info | grep "Fingerprint" | awk '{print $NF}')

echo -e "${YW}Fingerprint detectado: $FINGERPRINT${CL}"
echo "Precisamos da senha do ROOT para conectar o PVE ao PBS:"
read -s PBS_PASSWORD

if pvesm status | grep -q "$DATASTORE_NAME"; then
    echo "Storage '$DATASTORE_NAME' já está adicionado ao PVE."
else
    pvesm add pbs "$DATASTORE_NAME" \
        --server 127.0.0.1 \
        --datastore "$DATASTORE_NAME" \
        --fingerprint "$FINGERPRINT" \
        --username "$PBS_USER" \
        --password "$PBS_PASSWORD" \
        --content backup
    echo "[OK] Storage adicionado ao PVE."
fi

echo -e "${GN}✅ Proxmox Backup Server instalado e integrado!${CL}"
echo -e "${YW}Painel disponível em: https://localhost:8007${CL}"
