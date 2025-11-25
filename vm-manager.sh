#!/bin/bash
# ==============================================================================
# PROXMOX VM MANAGER - ALEOGR-PC (v3.3 - Granular Control)
# ==============================================================================
# Gerenciamento de VMs com suporte a Cloud-Init, GPU Passthrough.
# Novidades: Navegação "Voltar" e Pinagem de CPU Manual.
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
    echo -e "${YW}VM Manager v3.3 (Custom CPU Pinning)${CL}"
    echo ""
}

# --- FUNÇÕES AUXILIARES ---

detect_gpu() {
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

configure_cpu_affinity() {
    local VMID=$1
    echo ""
    echo -e "${YW}--- CONFIGURAÇÃO DE CPU PINNING (i9-13900K) ---${CL}"
    echo "O isolamento de núcleos evita que o sistema mova a VM entre P-Cores e E-Cores."
    echo ""
    echo -e "Mapa de Núcleos do i9-13900K:"
    echo -e "  ${GN}P-Cores (Performance):${CL} 0-15 (0-7 Físicos, 8-15 HyperThreads)"
    echo -e "  ${BL}E-Cores (Eficiência):${CL}  16-31"
    echo ""
    echo "1) P-Cores (0-15)  -> Gaming / Cracking / Heavy Duty"
    echo "2) E-Cores (16-31) -> Background Services / Scans"
    echo "3) Manual          -> Você digita os núcleos (ex: 0-7)"
    echo "4) Nenhum          -> Deixar o Proxmox gerenciar (Padrão)"
    echo "0) Voltar (Não alterar)"
    echo ""
    read -p "Opção: " CPU_OPT

    case $CPU_OPT in
        1) 
            qm set "$VMID" --affinity "0-15"
            echo -e "${GN}Pinning aplicado: P-Cores (0-15)${CL}"
            ;;
        2) 
            qm set "$VMID" --affinity "16-31"
            echo -e "${BL}Pinning aplicado: E-Cores (16-31)${CL}"
            ;;
        3)
            read -p "Digite a lista de núcleos (ex: 0-3,8-11): " MANUAL_PIN
            if [ -n "$MANUAL_PIN" ]; then
                qm set "$VMID" --affinity "$MANUAL_PIN"
                echo -e "${YW}Pinning Manual aplicado: $MANUAL_PIN${CL}"
            else
                echo "Entrada vazia. Nenhuma alteração feita."
            fi
            ;;
        4)
            # Remove a afinidade se existir
            qm set "$VMID" --delete affinity
            echo "Pinning removido (Padrão)."
            ;;
        0)
            return
            ;;
        *)
            echo "Opção inválida."
            ;;
    esac
}

list_vms() {
    echo -e "${GN}--- LISTA DE VMS ATUAIS ---${CL}"
    qm list
    echo ""
    read -p "Pressione Enter para voltar..."
}

delete_vm() {
    echo -e "${RD}--- EXCLUIR VM ---${CL}"
    echo "Digite '0' para voltar ao menu principal."
    read -p "Digite o ID da VM para DELETAR: " VMID
    
    if [ "$VMID" == "0" ]; then return; fi
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
    echo "Digite '0' a qualquer momento para cancelar e voltar."
    
    TARGET_GPU=$(detect_gpu)
    if [ $? -ne 0 ]; then
        echo -e "${RD}Erro: Nenhuma GPU NVIDIA encontrada.${CL}"
        read -p "Enter para voltar..."
        return
    fi
    echo -e "${YW}GPU Detectada: $TARGET_GPU (NVIDIA RTX)${CL}"

    read -p "ID da VM (ex: 100): " VMID
    if [ "$VMID" == "0" ]; then return; fi
    if qm status "$VMID" >/dev/null 2>&1; then echo "${RD}Erro: ID já existe!${CL}"; sleep 2; return; fi
    
    read -p "Nome da VM: " VMNAME
    if [ "$VMNAME" == "0" ]; then return; fi

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

    qm set "$VMID" --balloon 0
    qm set "$VMID" --efidisk0 "$DEFAULT_STORAGE:0,efitype=4m"
    qm set "$VMID" --tpmstate0 "$DEFAULT_STORAGE:0,version=v2.0"
    qm set "$VMID" --scsi0 "$DEFAULT_STORAGE:${DISK_SIZE},cache=writeback,discard=on"

    if [ -n "$WIN_ISO" ]; then qm set "$VMID" --ide2 "$WIN_ISO,media=cdrom"; fi
    if [ -n "$VIRTIO_ISO" ]; then qm set "$VMID" --ide0 "$VIRTIO_ISO,media=cdrom"; fi

    # CHAMADA DA NOVA FUNÇÃO DE PINNING
    configure_cpu_affinity "$VMID"

    echo -e "${BL}>>> Aplicando GPU Passthrough...${CL}"
    qm set "$VMID" --hostpci0 "$TARGET_GPU,pcie=1,x-vga=1,rombar=1"
    qm set "$VMID" --vga none
    qm set "$VMID" --agent enabled=1
    qm set "$VMID" --tags "Gaming,Windows,GPU"

    echo -e "${GN}✅ VM Gamer ($VMID) criada com sucesso!${CL}"
    read -p "Enter para voltar..."
}

# --- FUNÇÃO: CRIAR VM LINUX (CLOUD-INIT) ---
create_vm() {
    echo -e "${GN}--- CRIAR VM LINUX (CLOUD-INIT) ---${CL}"
    
    echo "Selecione a Imagem Base:"
    echo "1) Debian 12 (Bookworm)"
    echo "2) Ubuntu 24.04 LTS (Noble)"
    echo "3) Kali Linux (Cloud)"
    echo "4) Custom URL"
    echo "0) Voltar ao Menu Principal"
    read -p "Opção: " IMG_OPT
    
    case $IMG_OPT in
        1) IMG_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"; IMG_NAME="debian12.qcow2" ;;
        2) IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"; IMG_NAME="ubuntu2404.img" ;;
        3) IMG_URL="https://kali.download/cloud-images/kali-2024.1/kali-linux-2024.1-cloud-generic-amd64.qcow2"; IMG_NAME="kali.qcow2" ;;
        4) read -p "Cole a URL direta: " IMG_URL; IMG_NAME="custom.qcow2" ;;
        0) return ;;
        *) echo "Opção inválida."; return ;;
    esac

    read -p "ID da VM: " VMID
    if qm status "$VMID" >/dev/null 2>&1; then echo "Erro: ID existe."; return; fi
    read -p "Nome: " VMNAME
    read -p "Cores (ex: 2): " CORES
    read -p "Memória MB (ex: 2048): " MEMORY
    
    echo "Baixando imagem..."
    wget -q --show-progress "$IMG_URL" -O "$TEMP_DIR/$IMG_NAME"
    
    echo "Criando VM..."
    # Kali e distros modernas performam melhor com CPU Host (AES-NI, etc)
    qm create "$VMID" --name "$VMNAME" --memory "$MEMORY" --cores "$CORES" --cpu host --net0 virtio,bridge="$DEFAULT_BRIDGE"
    
    qm importdisk "$VMID" "$TEMP_DIR/$IMG_NAME" "$DEFAULT_STORAGE"
    qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "$DEFAULT_STORAGE:vm-$VMID-disk-0,discard=on"
    qm set "$VMID" --ide2 "$DEFAULT_STORAGE:cloudinit"
    qm set "$VMID" --boot c --bootdisk scsi0
    qm set "$VMID" --serial0 socket --vga serial0
    qm set "$VMID" --ciuser "$DEFAULT_USER" --ipconfig0 ip=dhcp
    qm set "$VMID" --tags "Linux,CloudInit"
    
    echo "Expandindo disco (+32G)..."
    qm resize "$VMID" scsi0 "+32G"

    rm "$TEMP_DIR/$IMG_NAME"

    # CHAMADA DA NOVA FUNÇÃO DE PINNING
    configure_cpu_affinity "$VMID"

    echo -e "${GN}✅ VM Linux criada!${CL}"
    read -p "Enter..."
}

# --- MENU PRINCIPAL ---

while true; do
    header
    echo "1) Criar VM Linux (Cloud-Init + CPU Select)"
    echo -e "${YW}2) Criar VM Windows Gamer (GPU + P-Cores)${CL}"
    echo "3) Listar VMs"
    echo "4) Excluir VM"
    echo "0) Sair"
    echo ""
    read -p "Escolha: " OPTION

    case $OPTION in
        1) create_vm ;;
        2) create_gaming_vm ;;
        3) list_vms ;;
        4) delete_vm ;;
        0) exit 0 ;;
        *) echo "Opção inválida." ;;
    esac
done
