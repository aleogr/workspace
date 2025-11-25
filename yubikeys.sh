#!/bin/bash

# --- CONFIGURAÇÃO ---
MY_USER="aleogr"
MAPPING_FILE="/etc/Yubico/u2f_mappings"

# Verifica root
if [ "$EUID" -ne 0 ]; then 
  echo "Por favor, rode como root (sudo)."
  exit 1
fi

# 1. Preparação (Limpeza)
mkdir -p /etc/Yubico
# Remove arquivo antigo para começar limpo
rm "$MAPPING_FILE" 2>/dev/null

echo ">>> INICIANDO CADASTRO DE YUBIKEYS PARA: $MY_USER"
echo "---------------------------------------------------"

# Variável acumuladora (começa vazia)
# A estrutura final será: :chave1:chave2:chave3
ALL_KEYS_STRING=""
COUNT=1

# 2. Loop Infinito
while true; do
    echo ""
    echo "--- CHAVE #$COUNT ---"
    echo "1. Insira a YubiKey na porta USB."
    echo "2. Pressione [ENTER] para ler..."
    read

    echo ">>> TOQUE NA YUBIKEY AGORA (Quando piscar)..."
    
    # Captura bruta
    RAW_DATA=$(pamu2fcfg -n)
    
    # Sanitização (Crucial para evitar erros de ::)
    # Remove quebras de linha, espaços e remove o ':' inicial se o comando trouxer
    CLEAN_DATA=$(echo -n "$RAW_DATA" | tr -d '\n\r[:space:]' | sed 's/^://')

    if [ -n "$CLEAN_DATA" ]; then
        echo "✅ Chave capturada!"
        # Adiciona na lista acumulada com um separador ':' antes
        ALL_KEYS_STRING="${ALL_KEYS_STRING}:${CLEAN_DATA}"
    else
        echo "❌ Falha ao capturar. Tente novamente nesta mesma etapa? (s/n)"
        read -r RETRY
        if [[ "$RETRY" =~ ^[Ss]$ ]]; then
            continue
        fi
    fi

    echo ""
    read -p "Deseja adicionar MAIS UMA chave? (s/n): " CONTINUAR
    
    # Se a resposta não for 's' ou 'S', quebra o loop
    if [[ ! "$CONTINUAR" =~ ^[Ss]$ ]]; then
        break
    fi
    
    echo "Remova a chave atual e prepare a próxima."
    COUNT=$((COUNT+1))
done

# 3. Gravação Final
if [ -n "$ALL_KEYS_STRING" ]; then
    # Formato final: usuario:chave1:chave2...
    # A variável ALL_KEYS_STRING já começa com ':', então basta colar no usuário.
    echo "${MY_USER}${ALL_KEYS_STRING}" > "$MAPPING_FILE"
    
    # Ajusta permissões
    chmod 644 "$MAPPING_FILE"
    chown root:root "$MAPPING_FILE"
    
    echo ""
    echo "========================================"
    echo "CONCLUÍDO COM SUCESSO!"
    echo "Arquivo gerado em: $MAPPING_FILE"
    echo "Conteúdo:"
    cat "$MAPPING_FILE"
    echo "========================================"
    echo "Teste agora em outro terminal com 'sudo ls'"
else
    echo "Nenhuma chave foi gravada. O arquivo não foi criado."
fi
