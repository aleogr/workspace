#!/bin/bash
# 03-hardware-tune-v2.sh
# Objetivo: Otimizar Kernel i9/NVMe, ZFS RAM, Isolamento de GPU e Governor.

# --- CONFIGURAÇÕES ---
ZFS_ARC_GB=8            # Limite de RAM para ZFS (GB)
CPU_VENDOR="intel"      # "intel" ou "amd"
# MUDANÇA: 'powersave' é o modo "Balanceado" correto para Intel modernos
CPU_GOVERNOR="powersave" 
# ---------------------

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
    echo -e "${YW}Hardware Tune: i9-13900K + RTX 3090 Ti${CL}"
    echo ""
}

header_info

echo -e "${GN}>>> [1/7] Calculando parâmetros básicos...${CL}"
if [ "$CPU_VENDOR" == "intel" ]; then IOMMU_FLAG="intel_iommu=on"; else IOMMU_FLAG="amd_iommu=on"; fi
ZFS_BYTES=$(($ZFS_ARC_GB * 1024 * 1024 * 1024))
echo "Target ZFS ARC: ${ZFS_ARC_GB}GB"

echo -e "${GN}>>> [2/7] Aplicando Parâmetros de Boot (Kernel)...${CL}"
cp /etc/kernel/cmdline /etc/kernel/cmdline.bak

# PARAMETERS EXPLAINED:
# iommu=pt : Pass-through mode (Performance)
# pci=noaer : Silenciar erros de ASPM do Chipset Z790
# nvme_core... : Fix vital para WD SN850X não travar
# split_lock... : Fix vital para jogos no i9 (evita crash do host)
# video=... : Impede o Linux de sequestrar a GPU no boot (Host Hijack)
# initcall_blacklist=sysfb_init : Garante que o Framebuffer não toque na GPU
CMDLINE="$IOMMU_FLAG iommu=pt pci=noaer nvme_core.default_ps_max_latency_us=0 split_lock_detect=off video=efifb:off video=vesafb:off video=simplefb:off initcall_blacklist=sysfb_init"

echo "root=ZFS=rpool/ROOT/pve-1 boot=zfs $CMDLINE" > /etc/kernel/cmdline
proxmox-boot-tool refresh
echo "[OK] Bootloader atualizado."

echo -e "${GN}>>> [3/7] Configurando CPU Governor ($CPU_GOVERNOR)...${CL}"
apt install -y cpufrequtils
echo "GOVERNOR=\"$CPU_GOVERNOR\"" > /etc/default/cpufrequtils
systemctl disable ondemand --now > /dev/null 2>&1 || true
systemctl restart cpufrequtils
echo "[OK] CPU definida para modo Balanceado (Intel P-State)."

echo -e "${GN}>>> [4/7] Aplicando Fix KVM para Windows no i9 (MSRs)...${CL}"
echo "options kvm ignore_msrs=1 report_ignored_msrs=0" > /etc/modprobe.d/kvm.conf
echo "[OK] Fix MSRs aplicado."

echo -e "${GN}>>> [5/7] Configurando Limite de RAM ZFS...${CL}"
echo "options zfs zfs_arc_max=$ZFS_BYTES" > /etc/modprobe.d/zfs.conf
echo "[OK] ZFS limitado."

echo -e "${GN}>>> [6/7] Automatizando Isolamento da GPU (VFIO)...${CL}"
update-pciids > /dev/null 2>&1 || true

# Detecta IDs da Nvidia automaticamente
GPU_IDS=$(lspci -nn | grep -i nvidia | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}(?=\])' | tr '\n' ',' | sed 's/,$//')

if [ -z "$GPU_IDS" ]; then
    echo "${YW}[AVISO] Nenhuma GPU Nvidia detectada! (Normal se for VM)${CL}"
else
    echo "GPU Nvidia detectada: $GPU_IDS"
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
    echo "[OK] GPU isolada e drivers Nvidia bloqueados."
fi

echo -e "${GN}>>> [7/7] Atualizando Initramfs...${CL}"
update-initramfs -u -k all

echo -e "${GN}✅ Otimizações Concluídas! REINICIE O SERVIDOR AGORA.${CL}"
