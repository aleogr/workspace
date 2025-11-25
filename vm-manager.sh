#!/bin/bash
# ==============================================================================
# PROXMOX VM MANAGER - ALEOGR (v3.2 - Organized Menu)
# ==============================================================================
# Gerenciamento de VMs com suporte a Cloud-Init, GPU Passthrough e
# Otimização de CPU Híbrida (P-Cores vs E-Cores).
# ==============================================================================

# --- CONFIGURAÇÕES PADRÃO ---
DEFAULT_STORAGE="VM-Storage"
ISO_STORAGE="local" 
DEFAULT_BRIDGE="vmbr0"
DEFAULT_USER="aleogr"
TEMP_DIR="/var/lib/vz/template/iso"

# Cores
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")

header() {
    clear
    echo -e "${BL}"
    cat << "EOF"
   __   __   ____   ___   ___   ____ 
  / _\ (  ) (  __) / _ \ / __) (  _ \
 /    \/ (_/\) _) ( (_) )( (_ \  )   /
 \_/\_/\____/(____) \___/  \___/ (__\_)
EOF
    echo -e "${CL}"
    echo -e "${YW}VM Manager v3.2${CL}"
    echo ""
}

# --- FUNÇÕES AUXILIARES ---

detect_gpu() {
    # Pega o ID (ex: 01:00.0) e remove o .0 final para pegar o slot inteiro
    GPU_RAW=$(lspci -nn | grep -i "NVIDIA" | grep -i "VGA" | head -n 1 | awk '{print $1}')
    if [ -z "$GPU_RAW" ]; then
        echo "Nenhuma GPU NVIDIA detectada."
        return 1
    else
        SHORT_ID=$(echo "$GPU_RAW" | cut -d. -f1)
        echo "0000:$SHORT_ID"
        return 0
    fi
}

find_iso() {
    SEARCH_TERM=$1
    pvesm list $ISO_STORAGE --content iso | grep -i "$SEARCH_TERM" | head -n 1 | awk '{print $1}'
}

list_vms() {
    echo -e "${GN}--- LISTA DE VMS ATUAIS ---${CL}"
    qm list
    echo ""
    read -p "Pressione Enter para voltar..."
}

delete_vm() {
    echo -e "${RD}--- EXCLUIR VM ---${CL}"
    read -p "Digite o ID da VM para DELETAR: " VMID
    
    if [ -z "$VMID" ]; then echo "ID inválido."; sleep 1; return; fi

    if ! qm status "$VMID" >/dev/null 2>&1; then
        echo -e "${RD}Erro: VM $VMID não encontrada.${CL}"
        sleep 2
        return
    fi
    
    VMNAME=$(qm config "$VMID" | grep name | awk '{print $2}')
    
    echo -e "${YW}Você vai excluir a VM: $VMID ($VMNAME)${CL}"
    echo -e "${RD}TODA A DATA SERÁ PERDIDA (Purge Disks).${CL}"
    read -p "Digite 'CONFIRMAR' para prosseguir: " CONFIRM
    
    if [ "$CONFIRM" == "CONFIRMAR" ]; then
        echo "Parando VM..."
        qm stop "$VMID" >/dev/null 2>&1
        echo "Destruindo VM e discos..."
        qm destroy "$VMID" --purge
        echo -e "${GN}VM $VMID excluída com sucesso.${CL}"
    else
        echo "Operação cancelada."
    fi
    sleep 2
}

# --- FUNÇÃO: CRIAR VM GAMER (WINDOWS GPU) ---
create_gaming_vm() {
    echo -e "${GN}--- CRIAR VM GAMER (WIN11 + GPU) ---${CL}"
    
    TARGET_GPU=$(detect_gpu)
    if [ $? -ne 0 ]; then
        echo -e "${RD}Erro: Nenhuma GPU NVIDIA encontrada.${CL}"
        read -p "Enter para voltar..."
        return
    fi
    echo -e "${YW}GPU Detectada: $TARGET_GPU (NVIDIA RTX)${CL}"

    read -p "ID da VM (ex: 100): " VMID
    if qm status "$VMID" >/dev/null 2>&1; then echo "${RD}Erro: ID já existe!${CL}"; sleep 2; return; fi
    
    read -p "Nome da VM: " VMNAME
    read -p "Cores (Recomendado 8): " CORES
    read -p "Memória MB (Recomendado 32768): " MEMORY
    read -p "Tamanho Disco GB: " DISK_SIZE

    echo "Procurando ISOs..."
    WIN_ISO=$(find_iso "win11")
    VIRTIO_ISO=$(find_iso "virtio")

    if [ -z "$WIN_ISO" ]; then
        echo -e "${RD}Aviso: ISO do Windows 11 não encontrada.${CL}"
        read -p "Cole o caminho completo da ISO: " WIN_ISO
    else
        echo -e "${GN}Windows ISO: $WIN_ISO${CL}"
    fi

    echo -e "${BL}>>> Criando estrutura da VM...${CL}"
    
    qm create "$VMID" --name "$VMNAME" --memory "$MEMORY" --cores "$CORES" \
        --machine q35 --bios ovmf --cpu host --numa 1 \
        --net0 virtio,bridge="$DEFAULT_BRIDGE" \
        --ostype win11 --scsihw virtio-scsi-pci

    # Ajustes Gamer
    qm set "$VMID" --balloon 0
    qm set "$VMID" --efidisk0 "$DEFAULT_STORAGE:0,efitype=4m"
    qm set "$VMID" --tpmstate0 "$DEFAULT_STORAGE:0,version=v2.0"
    qm set "$VMID" --scsi0 "$DEFAULT_STORAGE:${DISK_SIZE},cache=writeback,discard=on"

    if [ -n "$WIN_ISO" ]; then qm set "$VMID" --ide2 "$WIN_ISO,media=cdrom"; fi
    if [ -n "$VIRTIO_ISO" ]; then qm set "$VMID" --ide0 "$VIRTIO_ISO,media=cdrom"; fi

    # CPU PINNING (Windows sempre nos P-Cores)
    echo -e "${YW}Aplicando CPU Pinning (P-Cores 0-15) para estabilidade...${CL}"
    qm set "$VMID" --affinity "0-15"

    # GPU PASSTHROUGH
    echo -e "${BL}>>> Aplicando GPU Passthrough...${CL}"
    qm set "$VMID" --hostpci0 "$TARGET_GPU,pcie=1,x-vga=1,rombar=1"
    qm set "$VMID" --vga none
    qm set "$VMID" --agent enabled=1
    qm set "$VMID" --tags "Gaming,Windows,GPU"

    echo -e
