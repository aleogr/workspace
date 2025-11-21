#!/bin/bash
# 05-final-polish-v2.sh
# Objetivo: Ajustar uso de Swap.

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
    echo -e "${YW}Final Polish: Memory Tuning${CL}"
    echo ""
}

header_info

echo -e "${GN}>>> Ajustando Swappiness (Priorizar RAM)...${CL}"

SWAP_VALUE=10
sysctl vm.swappiness=$SWAP_VALUE

CONFIG_FILE="/etc/sysctl.d/99-pve-swappiness.conf"
echo "# Configuração customizada para Proxmox ZFS" > "$CONFIG_FILE"
echo "vm.swappiness=$SWAP_VALUE" >> "$CONFIG_FILE"

sysctl --system > /dev/null

echo -e "${GN}✅ Swappiness configurado para $SWAP_VALUE.${CL}"
echo -e "${BL}🚀 Setup Completo! Seu Proxmox está pronto para produção.${CL}"
