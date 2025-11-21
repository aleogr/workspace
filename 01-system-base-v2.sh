#!/bin/bash
# 01-system-base-v2.sh
# Objetivo: Resetar repositórios (Debian + PVE + PBS + Ceph), atualizar e aplicar Tweaks de UI.
# Inspirado em: Proxmox VE Helper-Scripts (tteck)

# --- CONFIGURAÇÃO ---
DEBIAN_CODENAME="trixie"
# --------------------

set -e

# Cores para output (Estilo Helper-Scripts)
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
 /    \/ (_/\) _)(  O ( (_ \ )   /
 \_/\_/\____/(____)\__/ \___/(__\_)
    ${CL}"
    echo -e "${YW}Target: i9-13900K + RTX 3090 Ti${CL}"
    echo ""
}

header_info

echo -e "${GN}>>> [1/7] Backup das listas antigas...${CL}"
mkdir -p /etc/apt/sources.list.d/backup_old
mv /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/backup_old/ 2>/dev/null || true
mv /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/backup_old/ 2>/dev/null || true

if [ -f /etc/apt/sources.list ]; then
    echo "# Repositórios movidos para /etc/apt/sources.list.d/debian.sources" > /etc/apt/sources.list
fi

echo -e "${GN}>>> [2/7] Criando Repositórios BASE DEBIAN...${CL}"
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

echo -e "${GN}>>> [3/7] Criando Repositórios PROXMOX (PVE + PBS + CEPH)...${CL}"
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

echo -e "${GN}>>> [4/7] Atualizando catálogos...${CL}"
apt update

echo -e "${GN}>>> [5/7] Atualizando sistema (Dist-Upgrade)...${CL}"
apt dist-upgrade -y

echo -e "${GN}>>> [6/7] Instalando Ferramentas Base e Microcode...${CL}"
# Adicionado 'ethtool' e 'net-tools' (comum nos scripts de otimização)
apt install -y intel-microcode build-essential pve-headers vim htop btop curl git fastfetch ethtool net-tools

echo -e "${GN}>>> [7/7] Aplicando Tweaks de Interface (Nag Removal)...${CL}"
if [ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]; then
    sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid subscription'\),)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
    systemctl restart pveproxy.service
    echo -e "${BL}[INFO] Aviso de Assinatura Removido.${CL}"
fi

echo -e "${GN}>>> Limpeza final...${CL}"
apt autoremove -y && apt clean

echo -e "${GN}✅ Base do Sistema Pronta!${CL}"
