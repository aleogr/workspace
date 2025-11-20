#!/bin/bash
# 01-system-prep.sh
# Objetivo: Configurar repositórios (formato moderno DEB822), atualizar base e instalar microcode.

# --- VARIÁVEIS DE CONFIGURAÇÃO ---
DEBIAN_CODENAME="trixie"  # Debian 13 (Base do PVE 9)
# ---------------------------------

# Parar script se houver erro crítico
set -e

echo ">>> [1/5] Desativando repositórios Enterprise..."
# Comenta todas as linhas dos arquivos originais
FILES_TO_DISABLE=(
    "/etc/apt/sources.list.d/pve-enterprise.sources"
    "/etc/apt/sources.list.d/ceph.sources"
)

for file in "${FILES_TO_DISABLE[@]}"; do
    if [ -f "$file" ]; then
        sed -i 's/^[^#]/#&/' "$file"
        echo "[OK] Desativado: $file"
    fi
done

echo ">>> [2/5] Criando repositórios No-Subscription (Formato DEB822)..."

# Cria o arquivo no formato novo e estruturado
cat <<EOF > /etc/apt/sources.list.d/pve-no-subscription.sources
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: $DEBIAN_CODENAME
Components: pve-no-subscription
Signed-By: /etc/apt/trusted.gpg.d/proxmox-release-$DEBIAN_CODENAME.gpg

Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: $DEBIAN_CODENAME
Components: no-subscription
Signed-By: /etc/apt/trusted.gpg.d/proxmox-release-$DEBIAN_CODENAME.gpg
EOF

echo "[OK] Arquivo /etc/apt/sources.list.d/pve-no-subscription.sources criado."

echo ">>> [3/5] Atualizando sistema e instalando base..."
apt update && apt dist-upgrade -y

echo ">>> [4/5] Instalando Intel Microcode e Ferramentas Essenciais..."
# intel-microcode: CRÍTICO para o seu i9-13900K (correções de CPU)
# build-essential/headers: Necessários para compilar drivers se preciso
apt install -y intel-microcode build-essential pve-headers vim htop btop curl git software-properties-common

echo ">>> [5/5] Limpeza e Manutenção..."
# Remove pacotes órfãos e limpa o cache do apt para economizar espaço
apt autoremove -y && apt clean

echo "✅ Preparação Concluída com Sucesso!"
