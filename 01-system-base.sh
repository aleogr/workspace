#!/bin/bash
# 01-system-base.sh
# Objetivo: Resetar repositórios (Debian + PVE + PBS + Ceph) e atualizar.

# --- VARIÁVEIS ---
DEBIAN_CODENAME="trixie"
# -----------------

set -e

echo ">>> [1/6] Backup das listas antigas..."
mkdir -p /etc/apt/sources.list.d/backup_old
mv /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/backup_old/ 2>/dev/null || true
mv /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/backup_old/ 2>/dev/null || true

if [ -f /etc/apt/sources.list ]; then
    echo "# Repositórios movidos para /etc/apt/sources.list.d/debian.sources" > /etc/apt/sources.list
fi

echo ">>> [2/6] Criando Repositórios BASE DEBIAN..."
cat <<EOF > /etc/apt/sources.list.d/debian.sources
Types: deb
URIs: http://deb.debian.org/debian
Suites: $DEBIAN_CODENAME $DEBIAN_CODENAME-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: $DEBIAN_CODENAME-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

echo ">>> [3/6] Criando Repositórios PROXMOX (PVE + PBS + CEPH)..."
cat <<EOF > /etc/apt/sources.list.d/pve-no-subscription.sources
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: $DEBIAN_CODENAME
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-release-$DEBIAN_CODENAME.gpg

Types: deb
URIs: http://download.proxmox.com/debian/pbs
Suites: $DEBIAN_CODENAME
Components: pbs-no-subscription
Signed-By: /usr/share/keyrings/proxmox-release-$DEBIAN_CODENAME.gpg

Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: $DEBIAN_CODENAME
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-release-$DEBIAN_CODENAME.gpg
EOF

echo ">>> [4/6] Atualizando catálogos..."
apt update

echo ">>> [5/6] Atualizando sistema..."
apt dist-upgrade -y

echo ">>> [6/6] Instalando Ferramentas Base..."
apt install -y intel-microcode build-essential pve-headers vim htop btop curl git

echo ">>> Limpeza..."
apt autoremove -y && apt clean

echo "✅ Base do Sistema (Com suporte a PBS) Pronta!"
