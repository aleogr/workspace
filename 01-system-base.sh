#!/bin/bash
# 01-system-base.sh
# Objetivo: Resetar e Configurar repositórios (Debian Base + Proxmox) no formato moderno.

# --- VARIÁVEIS ---
DEBIAN_CODENAME="trixie"  # Debian 13
# -----------------

set -e

echo ">>> [1/6] Fazendo backup das listas antigas..."
mkdir -p /etc/apt/sources.list.d/backup_old
# Move fontes antigas para backup se existirem
mv /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/backup_old/ 2>/dev/null || true
mv /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/backup_old/ 2>/dev/null || true

# Esvazia a lista principal antiga (mas mantém o arquivo vazio para o APT não reclamar)
if [ -f /etc/apt/sources.list ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.d/backup_old/sources.list.bak
    echo "# Repositórios movidos para /etc/apt/sources.list.d/debian.sources" > /etc/apt/sources.list
fi

echo ">>> [2/6] Criando Repositórios BASE DEBIAN (Debian.sources)..."
cat <<EOF > /etc/apt/sources.list.d/debian.sources
Types: deb
URIs: http://deb.debian.org/debian
Suites: $DEBIAN_CODENAME $DEBIAN_CODENAME-updates
Components: main contrib non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: $DEBIAN_CODENAME-security
Components: main contrib non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

echo ">>> [3/6] Criando Repositórios PROXMOX (No-Subscription)..."
cat <<EOF > /etc/apt/sources.list.d/pve-no-subscription.sources
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: $DEBIAN_CODENAME
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-release-$DEBIAN_CODENAME.gpg

Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: $DEBIAN_CODENAME
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-release-$DEBIAN_CODENAME.gpg
EOF

echo ">>> [4/6] Atualizando catálogos..."
apt update

echo ">>> [5/6] Atualizando sistema (Dist-Upgrade)..."
apt dist-upgrade -y

echo ">>> [6/6] Instalando Intel Microcode e Ferramentas..."
# Agora o apt vai encontrar tudo, pois configuramos o debian.sources acima
apt install -y intel-microcode build-essential pve-headers vim htop btop curl git software-properties-common

echo ">>> Limpeza final..."
apt autoremove -y && apt clean

echo "✅ Sistema Base Configurado com Sucesso!"
