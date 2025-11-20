#!/bin/bash
# 03-hardware-tune.sh
# Objetivo: Ajuste fino de Kernel e ZFS.

# --- VARIÁVEIS DE CONFIGURAÇÃO (EDITE AQUI) ---
ZFS_ARC_GB=8            # Limite de RAM para o ZFS em Gigabytes
CPU_VENDOR="intel"      # "intel" ou "amd"
# ----------------------------------------------

echo ">>> [1/4] Calculando parâmetros..."

# 1. Define IOMMU baseado no vendor
if [ "$CPU_VENDOR" == "intel" ]; then
    IOMMU_FLAG="intel_iommu=on"
else
    IOMMU_FLAG="amd_iommu=on"
fi

# 2. Converte GB para Bytes para o ZFS (GB * 1024^3)
ZFS_BYTES=$(($ZFS_ARC_GB * 1024 * 1024 * 1024))
echo "Target ZFS ARC: ${ZFS_ARC_GB}GB ($ZFS_BYTES bytes)"

echo ">>> [2/4] Aplicando Parâmetros de Kernel..."
# Backup
cp /etc/kernel/cmdline /etc/kernel/cmdline.bak

# Lista de parâmetros vitais para seu i9-13900K + 3090 Ti + WD SN850X
# split_lock_detect=off -> Vital para jogos no i9
# nvme_core... -> Vital para WD SN850X
# video=... -> Vital para evitar Host Hijack da GPU
CMDLINE="$IOMMU_FLAG iommu=pt pci=noaer nvme_core.default_ps_max_latency_us=0 split_lock_detect=off video=efifb:off video=vesafb:off video=simplefb:off"

echo "root=ZFS=rpool/ROOT/pve-1 boot=zfs $CMDLINE" > /etc/kernel/cmdline
proxmox-boot-tool refresh
echo "[OK] Bootloader atualizado."

echo ">>> [3/4] Configurando ZFS..."
echo "options zfs zfs_arc_max=$ZFS_BYTES" > /etc/modprobe.d/zfs.conf
update-initramfs -u
echo "[OK] Limite de memória ZFS aplicado."

echo ">>> [4/4] Configurando Blacklist Nvidia..."
cat <<EOF > /etc/modprobe.d/blacklist.conf
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
EOF

echo "✅ Otimizações aplicadas! REINICIE O SERVIDOR."
