#!/bin/bash
# =================================================================
# 05-final-polish.sh (Versão Corrigida - Systemd Style)
# Objetivo: Ajustar uso de Swap usando diretórios de configuração modernos.
# =================================================================

set -e

echo ">>> Ajustando Swappiness (Priorizar RAM ao invés de Disco)..."

# VALOR IDEAL:
# 60 = Padrão Desktop (Usa swap cedo)
# 10 = Recomendado para ZFS (Usa swap só em emergência)
SWAP_VALUE=10

# 1. Aplica na hora (Runtime)
sysctl vm.swappiness=$SWAP_VALUE

# 2. Torna permanente (Persistência)
# Em vez de editar /etc/sysctl.conf, criamos um arquivo dedicado em .d
# Isso é mais limpo e evita erros de "File not found".

CONFIG_FILE="/etc/sysctl.d/99-pve-swappiness.conf"

echo "# Configuração customizada para Proxmox ZFS" > "$CONFIG_FILE"
echo "vm.swappiness=$SWAP_VALUE" >> "$CONFIG_FILE"

echo ">>> Configuração salva em: $CONFIG_FILE"

# Recarrega as configurações de sistema para garantir
sysctl --system > /dev/null

echo "✅ Swappiness configurado para $SWAP_VALUE."
echo "🚀 Setup Completo! Seu Proxmox está pronto para produção."
