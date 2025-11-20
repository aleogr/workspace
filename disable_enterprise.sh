#!/bin/bash

# --- CONFIGURAÇÃO ---
FILES_TO_DISABLE=(
    "/etc/apt/sources.list.d/pve-enterprise.sources"
    "/etc/apt/sources.list.d/ceph.sources"
)

MAIN_LIST="/etc/apt/sources.list"

# --- PASSO 1: Comentar repositórios Enterprise ---
echo ">>> [1/3] Processando arquivos Enterprise..."

for file in "${FILES_TO_DISABLE[@]}"; do
    if [ -f "$file" ]; then
        # Backup
        cp "$file" "$file.bak"
        
        # Comenta linhas que não começam com #
        sed -i 's/^[^#]/#&/' "$file"
        echo "[OK] Desativado: $file"
    else
        echo "[SKIP] Arquivo não existe: $file"
    fi
done

# --- PASSO 2: Adicionar Repositórios No-Subscription ---
echo ">>> [2/3] Verificando repositórios No-Subscription em $MAIN_LIST..."

# Função para inserir o bloco de texto apenas se não encontrar uma palavra-chave
add_repo_if_missing() {
    local keyword="$1"
    local content="$2"

    if grep -q "$keyword" "$MAIN_LIST"; then
        echo "[INFO] Repositório contendo '$keyword' já existe. Nada a fazer."
    else
        echo "" >> "$MAIN_LIST"
        echo -e "$content" >> "$MAIN_LIST"
        echo "[OK] Adicionado bloco: $keyword"
    fi
}

# Conteúdo para o PVE (Trixie)
PVE_CONTENT="# PVE No-Subscription (Gratuito)
deb http://download.proxmox.com/debian/pve trixie pve-no-subscription"

# Conteúdo para o Ceph (Squid/Trixie)
CEPH_CONTENT="# Ceph No-Subscription (Gratuito) - Importante para evitar conflito de versões
deb http://download.proxmox.com/debian/ceph-squid trixie no-subscription"

# Executa as verificações
add_repo_if_missing "pve-no-subscription" "$PVE_CONTENT"
add_repo_if_missing "ceph-squid" "$CEPH_CONTENT"

# --- PASSO 3: Atualizar ---
echo ">>> [3/3] Atualizando listas do apt..."
apt update

echo ">>> Concluído com sucesso."
