#!/bin/bash
# 03-hardware-tune.sh (Versão Ultimate Passthrough)
# Objetivo: Otimizar Kernel i9/NVMe, ZFS RAM e Automatizar Isolamento de GPU.

# --- VARIÁVEIS ---
ZFS_ARC_GB=8       # Limite de RAM para ZFS
CPU_VENDOR="intel" # intel ou amd
# -----------------

set -e

echo ">>> [1/6] Calculando parâmetros básicos..."
if [ "$CPU_VENDOR" == "intel" ]; then IOMMU_FLAG="intel_iommu=on"; else IOMMU_FLAG="amd_iommu=on"; fi
ZFS_BYTES=$(($ZFS_ARC_GB * 1024 * 1024 * 1024))

echo ">>> [2/6] Aplicando Parâmetros de Boot (Kernel)..."
cp /etc/kernel/cmdline /etc/kernel/cmdline.bak

# Explicação dos Parâmetros:
# iommu=pt : Pass-through mode (melhor performance)
# pci=noaer : Evita inundação de logs de erro PCIe
# nvme_core... : Fix para WD SN850X não travar em low-power
# split_lock... : Fix para i9-13900K não travar em jogos
# video=... : Desliga drivers de vídeo do Linux para liberar a GPU
CMDLINE="$IOMMU_FLAG iommu=pt pci=noaer nvme_core.default_ps_max_latency_us=0 split_lock_detect=off video=efifb:off video=vesafb:off video=simplefb:off" initcall_blacklist=sysfb_init

echo "root=ZFS=rpool/ROOT/pve-1 boot=zfs $CMDLINE" > /etc/kernel/cmdline
proxmox-boot-tool refresh
echo "[OK] Bootloader atualizado."

echo ">>> [3/6] Aplicando Fix KVM para Windows no i9 (MSRs)..."
echo "options kvm ignore_msrs=1 report_ignored_msrs=0" > /etc/modprobe.d/kvm.conf
echo "[OK] Fix MSRs aplicado."

echo ">>> [4/6] Configurando Limite de RAM ZFS..."
echo "options zfs zfs_arc_max=$ZFS_BYTES" > /etc/modprobe.d/zfs.conf
echo "[OK] ZFS limitado a ${ZFS_ARC_GB}GB."

echo ">>> [5/6] Automatizando Isolamento da GPU (VFIO)..."
update-pciids > /dev/null 2>&1 || true

GPU_IDS=$(lspci -nn | grep -i nvidia | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}(?=\])' | tr '\n' ',' | sed 's/,$//')

if [ -z "$GPU_IDS" ]; then
    echo "[AVISO] Nenhuma GPU Nvidia detectada! Pulando configuração VFIO."
    echo "Se você estiver rodando isso no VirtualBox, é normal."
else
    echo "GPU Nvidia detectada com IDs: $GPU_IDS"
    echo "options vfio-pci ids=$GPU_IDS disable_vga=1" > /etc/modprobe.d/vfio.conf
    echo "vfio" > /etc/modules
    echo "vfio_iommu_type1" >> /etc/modules
    echo "vfio_pci" >> /etc/modules
    echo "vfio_virqfd" >> /etc/modules
    cat <<EOF > /etc/modprobe.d/blacklist.conf
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
EOF
    echo "[OK] GPU isolada e drivers Nvidia bloqueados no Host."
fi

echo ">>> [6/6] Atualizando Initramfs..."
update-initramfs -u -k all

echo "✅ Otimizações de Hardware Concluídas! REINICIE AGORA."
