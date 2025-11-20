#!/bin/bash

# Lista dos arquivos que queremos comentar
FILES=(
    "/etc/apt/sources.list.d/pve-enterprise.list"
    "/etc/apt/sources.list.d/ceph.list"
)

echo "Iniciando o processo de comentar repositórios Enterprise..."

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        # Faz um backup antes de alterar (boa prática)
        cp "$file" "$file.bak"
        
        # O comando sed adiciona um # no início de qualquer linha que NÃO comece com #
        sed -i 's/^[^#]/#&/' "$file"
        
        echo "[OK] Arquivo $file comentado com sucesso."
    else
        echo "[INFO] O arquivo $file não foi encontrado. Pulando."
    fi
done

echo "Concluído."