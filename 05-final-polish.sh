#!/bin/bash
# 05-final-polish.sh
# Objetivo: Ajustar uso de Swap (Swappiness) para priorizar performance do ZFS.

echo ">>> Ajustando Swappiness (Evitar uso de disco desnecessário)..."

# O padrão do Linux é 60. Para servidores ZFS, recomendamos entre 1 e 10.
# Isso diz ao Linux: "Só use o arquivo de troca se a RAM estiver CRITICAMENTE cheia".

# Aplica na hora
sysctl vm.swappiness=10

# Torna permanente
if grep -q "vm.swappiness" /etc/sysctl.conf; then
    sed -i 's/^vm.swappiness.*/vm.swappiness=10/' /etc/sysctl.conf
else
    echo "vm.swappiness=10" >> /etc/sysctl.conf
fi

echo "✅ Swappiness configurado para 10."
echo "Setup Completo! Seu Proxmox está pronto para produção."
