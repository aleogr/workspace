#!/bin/bash

# --- CONFIGURAÇÃO PARA PROXMOX VE 9.x (Debian 13) ---
FILES_TO_DISABLE=(
    "/etc/apt/sources.list.d/pve-enterprise.sources"
    "/etc/apt/sources.list.d/ceph.sources"
)

MAIN_LIST="/etc/apt/sources.list"

# --- PASSO 1: Comentar repositórios Enterprise ---
echo ">>> [1/3] Processando arquivos Enterprise (PVE 9)..."

for file in "${FILES_TO_DISABLE[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$file.bak"
        # Comenta qualquer linha que não comece com #
        sed -i 's/^[^#]/#&/' "$file"
        echo "[OK] Desativado: $file"
    else
        echo "[SKIP] Arquivo não encontrado: $file (Normal se for instalação limpa)"
    fi
done

# --- PASSO 2: Adicionar Repositórios No-Subscription (TRIXIE) ---
echo ">>> [2/3] Configurando repositórios Trixie & Ceph Squid..."

add_repo_if_missing() {
    local keyword="$1"
    local content="$2"
    if grep -q "$keyword" "$MAIN_LIST"; then
        echo "[INFO] Repositório '$keyword' já existe."
    else
        echo "" >> "$MAIN_LIST"
        echo -e "$content" >> "$MAIN_LIST"
        echo "[OK] Adicionado: $keyword"
    fi
}

# PVE 9 (Trixie / Debian 13)
PVE_CONTENT="# PVE 9 No-Subscription (Gratuito)
deb http://download.proxmox.com/debian/pve trixie pve-no-subscription"

# Ceph Squid (Padrão do PVE 9)
CEPH_CONTENT="# Ceph Squid No-Subscription
deb http://download.proxmox.com/debian/ceph-squid trixie no-subscription"

add_repo_if_missing "pve-no-subscription" "$PVE_CONTENT"
add_repo_if_missing "ceph-squid" "$CEPH_CONTENT"

# --- PASSO 3: Atualizar ---
echo ">>> [3/3] Atualizando listas do apt..."
apt update

echo ">>> Concluído! Agora você pode rodar 'apt dist-upgrade' para atualizar o sistema."
