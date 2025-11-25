#!/bin/bash
# ==============================================================================
# PROXMOX VM MANAGER - ALEOGR (v4.8 - Multi-Arch Tags)
# ==============================================================================
# Gerenciamento de VMs com suporte a Múltiplos SOs, Cloud-Init e GPU.
# Tags Dinâmicas: Identifica corretamente amd64 vs arm64.
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
    echo -e "${YW}VM Manager v4.8 (Dynamic Tags)${CL}"
    echo ""
}

# --- FUNÇÕES AUXILIARES ---

detect_gpu() {
    GPU_RAW=$(lspci -nn | grep -i "NVIDIA" | grep -i "VGA" | head -n 1 | awk '{print $1}')
    if [ -z "$GPU_RAW" ]; then
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
    echo -e "${YW}--- CPU PINNING (i9-13900K) ---${CL}"
    echo "1) P-Cores (0-15)  -> Performance Máxima"
    echo "2) E-Cores (16-31) -> Background/Serviços"
    echo "3) Manual          -> Definir lista (ex: 0-7)"
    echo "4) Padrão          -> Automático do Proxmox"
    echo "0) Voltar"
    read -p "Opção: " CPU_OPT

    case $CPU_OPT in
        1) qm set "$VMID" --affinity "0-15"; echo -e "${GN}P-Cores.${CL}" ;;
        2) qm set "$VMID" --affinity "16-31"; echo -e "${BL}E-Cores.${CL}" ;;
        3) read -p "Núcleos: " MP; qm set "$VMID" --affinity "$MP"; ;;
        4) qm set "$VMID" --delete affinity ;;
        *) return ;;
    esac
}

# --- DASHBOARD ---
manage_vms() {
    while true; do
        header
        echo -e "${GN}--- DASHBOARD DE VMS ---${CL}"
        # Ajustado layout para caber tags maiores
        printf "${YW}%-5s | %-18s | %-8s | %-4s | %-8s | %-12s | %-25s${CL}\n" "ID" "NOME" "STATUS" "CPU" "RAM" "DISPLAY" "TAGS"
        echo "--------------------------------------------------------------------------------------------"

        for vmid in $(qm list | awk 'NR>1 {print $1}' | sort -n); do
            CONF=$(qm config $vmid)
            NAME=$(echo "$CONF" | grep "^name:" | awk '{print $2}')
            STATUS=$(qm status $vmid | awk '{print $2}')
            CORES=$(echo "$CONF" | grep "^cores:" | awk '{print $2}')
            [ -z "$CORES" ] && CORES="1"
            MEM=$(echo "$CONF" | grep "^memory:" | awk '{print $2}')
            TAGS=$(echo "$CONF" | grep "^tags:" | cut -d: -f2 | tr -d ' ')
            
            if echo "$CONF" | grep -q "hostpci0"; then DISPLAY="GPU"; else
                DISPLAY=$(echo "$CONF" | grep "^vga:" | awk '{print $2}')
                [ -z "$DISPLAY" ] && DISPLAY="Std"
            fi

            if [ "$STATUS" == "running" ]; then S_COLOR=$GN; else S_COLOR=$RD; fi

            printf "%-5s | %-18s | ${S_COLOR}%-8s${CL} | %-4s | %-8s | %-12s | %-25s\n" \
                "$vmid" "${NAME:0:18}" "$STATUS" "$CORES" "${MEM}MB" "$DISPLAY" "${TAGS:0:25}"
        done
        echo "--------------------------------------------------------------------------------------------"
        echo ""
        echo -e "${YW}Ações:${CL}"
        echo "Digite o ID da VM para [EXCLUIR]"
        echo "Digite 'r' para [ATUALIZAR]"
        echo "Pressione Enter para [VOLTAR] ao menu principal"
        echo ""
        read -p "> " ACTION

        if [ -z "$ACTION" ]; then return; fi
        if [ "$ACTION" == "r" ]; then continue; fi

        if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
            if ! qm status "$ACTION" >/dev/null 2>&1; then
                echo -e "${RD}VM $ACTION não encontrada.${CL}"; sleep 1; continue
            fi
            
            VMNAME_DEL=$(qm config "$ACTION" | grep name | awk '{print $2}')
            echo -e "${RD}!!! ATENÇÃO !!!${CL}"
            echo -e "Você vai DESTRUIR a VM: ${BL}$ACTION ($VMNAME_DEL)${CL}"
            echo -e "Todos os dados e discos serão apagados (Purge)."
            read -p "Digite 'CONFIRMAR' para prosseguir: " SURE
            
            if [ "$SURE" == "CONFIRMAR" ]; then
                qm stop "$ACTION" >/dev/null 2>&1
                qm destroy "$ACTION" --purge
                echo -e "${GN}VM Excluída.${CL}"
                sleep 2
            else
                echo "Cancelado."
                sleep 1
            fi
        fi
    done
}

# --- MÓDULO 1: WINDOWS GAMER ---
create_gaming_vm() {
    echo -e "${GN}--- WINDOWS 11 GAMER (GPU Passthrough) ---${CL}"
    TARGET_GPU=$(detect_gpu)
    if [ $? -ne 0 ]; then echo "${RD}Sem GPU Nvidia.${CL}"; read -p "Enter..."; return; fi

    read -p "ID da VM: " VMID
    read -p "Nome: " VMNAME
    
    echo "Procurando ISOs..."
    WIN_ISO=$(find_iso "win11")
    VIRTIO_ISO=$(find_iso "virtio")
    
    if [ -z "$WIN_ISO" ]; then read -p "Cole o caminho da ISO Windows: " WIN_ISO; fi

    qm create "$VMID" --name "$VMNAME" --memory 32768 --cores 8 \
        --machine q35 --bios ovmf --cpu host --numa 1 \
        --net0 virtio,bridge="$DEFAULT_BRIDGE" --ostype win11 --scsihw virtio-scsi-pci

    qm set "$VMID" --balloon 0 --efidisk0 "$DEFAULT_STORAGE:0,efitype=4m" \
        --tpmstate0 "$DEFAULT_STORAGE:0,version=v2.0" \
        --scsi0 "$DEFAULT_STORAGE:100,cache=writeback,discard=on"
    
    if [ -n "$WIN_ISO" ]; then qm set "$VMID" --ide2 "$WIN_ISO,media=cdrom"; fi
    if [ -n "$VIRTIO_ISO" ]; then qm set "$VMID" --ide0 "$VIRTIO_ISO,media=cdrom"; fi

    configure_cpu_affinity "$VMID"
    
    # Tags Windows
    qm set "$VMID" --hostpci0 "$TARGET_GPU,pcie=1,x-vga=1,rombar=1" \
        --vga none --agent enabled=1 \
        --tags "vm,windows,amd64,gpu"
    
    echo -e "${GN}VM Windows Gamer criada!${CL}"
    read -p "Enter..."
}

# --- MÓDULO 2: LINUX CLOUD (AUTO-INSTALL) ---
create_cloud_vm() {
    echo -e "${GN}--- LINUX CLOUD-INIT ---${CL}"
    echo "1) Debian 13 Trixie (Stable)"
    echo "2) Ubuntu 24.04 LTS (Noble)"
    echo "3) Kali Linux (2024.3)"
    echo "4) Fedora 43 Cloud"
    echo "5) Arch Linux Cloud"
    echo "6) CentOS Stream 9"
    echo "7) Rocky Linux 9"
    echo -e "${YW}8) Debian 13 ARM64 (Emulado - Lento)${CL}"
    echo -e "${YW}9) Ubuntu 24.04 ARM64 (Emulado - Lento)${CL}"
    echo "0) Voltar"
    read -p "Opção: " OPT

    # Definição de Variáveis baseada na escolha
    case $OPT in
        1) URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"; IMG="deb13.qcow2"; ARCH="amd64"; FAMILY="linux" ;;
        2) URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"; IMG="ubu24.img"; ARCH="amd64"; FAMILY="linux" ;;
        3) URL="https://kali.download/cloud-images/kali-rolling/kali-linux-rolling-cloud-generic-amd64.qcow2"; IMG="kali.qcow2"; ARCH="amd64"; FAMILY="linux" ;;
        4) URL="https://download.fedoraproject.org/pub/fedora/linux/releases/43/Cloud/x86_64/images/Fedora-Cloud-Base-Generic.x86_64-43-1.2.qcow2"; IMG="fedora.qcow2"; ARCH="amd64"; FAMILY="linux" ;;
        5) URL="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"; IMG="arch.qcow2"; ARCH="amd64"; FAMILY="linux" ;;
        6) URL="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"; IMG="centos9.qcow2"; ARCH="amd64"; FAMILY="linux" ;;
        7) URL="https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"; IMG="rocky9.qcow2"; ARCH="amd64"; FAMILY="linux" ;;
        # Opções ARM64
        8) URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-arm64.qcow2"; IMG="deb13-arm.qcow2"; ARCH="arm64"; FAMILY="linux" ;;
        9) URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img"; IMG="ubu24-arm.img"; ARCH="arm64"; FAMILY="linux" ;;
        *) return ;;
    esac

    read -p "ID: " VMID
    read -p "Nome: " VMNAME
    read -p "Cores (2): " CORES; [ -z "$CORES" ] && CORES=2
    read -p "RAM MB (2048): " RAM; [ -z "$RAM" ] && RAM=2048
    
    echo "Baixando imagem..."
    wget -q --show-progress "$URL" -O "$TEMP_DIR/$IMG"

    # Lógica de Criação Adaptativa (x86 vs ARM)
    if [ "$ARCH" == "arm64" ]; then
        echo -e "${YW}Criando VM ARM64 (Emulação)...${CL}"
        # ARM precisa de BIOS OVMF, Machine Virt e Serial Console
        qm create "$VMID" --name "$VMNAME" --memory "$RAM" --cores "$CORES" --net0 virtio,bridge="$DEFAULT_BRIDGE" \
            --arch aarch64 --bios ovmf --machine virt --cpu host
    else
        echo "Criando VM x86_64..."
        qm create "$VMID" --name "$VMNAME" --memory "$RAM" --cores "$CORES" --cpu host --net0 virtio,bridge="$DEFAULT_BRIDGE"
    fi

    qm importdisk "$VMID" "$TEMP_DIR/$IMG" "$DEFAULT_STORAGE"
    qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "$DEFAULT_STORAGE:vm-$VMID-disk-0,discard=on"
    
    # Cloud-Init e Boot
    qm set "$VMID" --ide2 "$DEFAULT_STORAGE:cloudinit" 
    qm set "$VMID" --boot c --bootdisk scsi0 
    qm set "$VMID" --serial0 socket --vga serial0
    qm set "$VMID" --ciuser "$DEFAULT_USER" --ipconfig0 ip=dhcp
    
    # Aplica as Tags Dinâmicas (vm, linux, amd64/arm64)
    qm set "$VMID" --tags "vm,${FAMILY},${ARCH}"

    echo "Expandindo disco (+32G)..."
    qm resize "$VMID" scsi0 "+32G"
    rm "$TEMP_DIR/$IMG"

    configure_cpu_affinity "$VMID"

    echo -e "${GN}VM Cloud criada!${CL}"
    read -p "Enter..."
}

# --- MÓDULO 3: LINUX ISO ---
create_iso_vm() {
    echo -e "${GN}--- LINUX MANUAL ISO ---${CL}"
    echo "1) Linux Mint 22 (Wilma)"
    echo "2) Kali Linux PURPLE (2024.3)"
    echo "3) Manjaro Gnome (Latest)"
    echo "4) Gentoo Minimal (Latest)"
    echo "0) Voltar"
    read -p "Opção: " OPT

    # Tags Padrão para ISO
    ARCH="amd64"
    FAMILY="linux"

    case $OPT in
        1) URL="https://mirrors.edge.kernel.org/linuxmint/stable/22/linuxmint-22-cinnamon-64bit.iso"; ISO="mint22.iso" ;;
        2) URL="https://cdimage.kali.org/kali-2024.3/kali-linux-2024.3-purple-installer-amd64.iso"; ISO="kali-purple.iso" ;;
        3) URL="https://download.manjaro.org/gnome/24.0.6/manjaro-gnome-24.0.6-240729-linux69.iso"; ISO="manjaro.iso" ;;
        4) URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/20241124T170335Z/install-amd64-minimal-20241124T170335Z.iso"; ISO="gentoo.iso" ;;
        *) return ;;
    esac

    ISO_PATH="$TEMP_DIR/$ISO"
    if [ ! -f "$ISO_PATH" ]; then
        echo "Baixando ISO..."
        wget -q --show-progress "$URL" -O "$ISO_PATH"
    fi

    read -p "ID: " VMID
    read -p "Nome: " VMNAME
    
    qm create "$VMID" --name "$VMNAME" --memory 4096 --cores 4 --cpu host --net0 virtio,bridge="$DEFAULT_BRIDGE" --ostype l26
    qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "$DEFAULT_STORAGE:64,cache=writeback,discard=on"
    qm set "$VMID" --ide2 "$ISO_STORAGE:iso/$ISO,media=cdrom"
    qm set "$VMID" --vga virtio --agent enabled=1
    
    qm set "$VMID" --tags "vm,${FAMILY},${ARCH}"

    configure_cpu_affinity "$VMID"

    echo -e "${GN}VM criada com ISO montada!${CL}"
    read -p "Enter..."
}

# --- MENU PRINCIPAL ---

while true; do
    header
    echo "1) Linux Cloud-Init (Multi-Arch)"
    echo "2) Linux Manual ISO (Mint, Gentoo)"
    echo -e "${YW}3) Windows 11 Gamer (GPU Passthrough)${CL}"
    echo -e "${BL}4) Gerenciar VMs (Dashboard/Excluir)${CL}"
    echo "0) Sair"
    echo ""
    read -p "Escolha: " OPTION

    case $OPTION in
        1) create_cloud_vm ;;
        2) create_iso_vm ;;
        3) create_gaming_vm ;;
        4) manage_vms ;;
        0) exit 0 ;;
        *) echo "Opção inválida." ;;
    esac
done
