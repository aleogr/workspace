#!/bin/bash
# ==============================================================================
# PROXMOX VM MANAGER - ALEOGR (v4.0 - OS Collection)
# ==============================================================================
# Gerenciamento de VMs com suporte a Múltiplos SOs, Cloud-Init e GPU.
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
    echo -e "${YW}VM Manager v4.0 (Multi-OS Edition)${CL}"
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

list_vms() {
    echo -e "${GN}--- LISTA DE VMS ---${CL}"
    qm list
    echo ""
    read -p "Enter para voltar..."
}

delete_vm() {
    echo -e "${RD}--- EXCLUIR VM ---${CL}"
    read -p "ID da VM: " VMID
    if [ -z "$VMID" ]; then return; fi
    
    VMNAME=$(qm config "$VMID" 2>/dev/null | grep name | awk '{print $2}')
    if [ -z "$VMNAME" ]; then echo "VM não encontrada."; sleep 1; return; fi

    echo -e "${YW}Excluir: $VMID ($VMNAME)? (Dados serão perdidos)${CL}"
    read -p "Digite 'CONFIRMAR': " CONFIRM
    
    if [ "$CONFIRM" == "CONFIRMAR" ]; then
        qm stop "$VMID" >/dev/null 2>&1
        qm destroy "$VMID" --purge
        echo -e "${GN}VM Excluída.${CL}"
    else
        echo "Cancelado."
    fi
    sleep 1
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
    
    qm set "$VMID" --hostpci0 "$TARGET_GPU,pcie=1,x-vga=1,rombar=1" --vga none --agent enabled=1 --tags "Gaming,Windows"
    
    echo -e "${GN}VM Windows Gamer criada!${CL}"
    read -p "Enter..."
}

# --- MÓDULO 2: LINUX CLOUD (AUTO-INSTALL) ---
create_cloud_vm() {
    echo -e "${GN}--- LINUX CLOUD-INIT (Instalação Automática) ---${CL}"
    echo "1) Debian 12 (Bookworm)"
    echo "2) Ubuntu 24.04 LTS"
    echo "3) Kali Linux (Standard)"
    echo "4) Fedora 41 Cloud"
    echo "5) Arch Linux Cloud"
    echo "0) Voltar"
    read -p "Opção: " OPT

    case $OPT in
        1) URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"; IMG="deb12.qcow2" ;;
        2) URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"; IMG="ubu24.img" ;;
        3) URL="https://kali.download/cloud-images/kali-2024.1/kali-linux-2024.1-cloud-generic-amd64.qcow2"; IMG="kali.qcow2" ;;
        4) URL="https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-Generic.x86_64-41-1.4.qcow2"; IMG="fedora.qcow2" ;;
        5) URL="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"; IMG="arch.qcow2" ;;
        *) return ;;
    esac

    read -p "ID: " VMID
    read -p "Nome: " VMNAME
    read -p "Cores (2): " CORES
    read -p "RAM MB (2048): " RAM
    
    [ -z "$CORES" ] && CORES=2
    [ -z "$RAM" ] && RAM=2048

    echo "Baixando imagem..."
    wget -q --show-progress "$URL" -O "$TEMP_DIR/$IMG"

    qm create "$VMID" --name "$VMNAME" --memory "$RAM" --cores "$CORES" --cpu host --net0 virtio,bridge="$DEFAULT_BRIDGE"
    qm importdisk "$VMID" "$TEMP_DIR/$IMG" "$DEFAULT_STORAGE"
    qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "$DEFAULT_STORAGE:vm-$VMID-disk-0,discard=on"
    qm set "$VMID" --ide2 "$DEFAULT_STORAGE:cloudinit" --boot c --bootdisk scsi0 --serial0 socket --vga serial0
    qm set "$VMID" --ciuser "$DEFAULT_USER" --ipconfig0 ip=dhcp
    qm set "$VMID" --tags "Cloud,Linux"

    echo "Expandindo disco (+32G)..."
    qm resize "$VMID" scsi0 "+32G"
    rm "$TEMP_DIR/$IMG"

    configure_cpu_affinity "$VMID"

    echo -e "${GN}VM Cloud criada! (User: $DEFAULT_USER / Sem senha inicial - Use Console para definir ou SSH Key)${CL}"
    read -p "Enter..."
}

# --- MÓDULO 3: LINUX DESKTOP (ISO INSTALL) ---
create_iso_vm() {
    echo -e "${GN}--- LINUX DESKTOP (Instalação via ISO) ---${CL}"
    echo "Estas distros não possuem Cloud-Init oficial estável."
    echo "O script baixará a ISO e montará a VM para você instalar graficamente."
    echo ""
    echo "1) Linux Mint 21.3 (Cinnamon)"
    echo "2) Kali Linux PURPLE (Security)"
    echo "3) Manjaro Gnome (Latest)"
    echo "0) Voltar"
    read -p "Opção: " OPT

    case $OPT in
        1) URL="https://mirrors.edge.kernel.org/linuxmint/stable/21.3/linuxmint-21.3-cinnamon-64bit.iso"; ISO="mint.iso"; OS="l26" ;;
        2) URL="https://cdimage.kali.org/kali-2024.1/kali-linux-2024.1-purple-installer-amd64.iso"; ISO="kali-purple.iso"; OS="l26" ;;
        3) URL="https://download.manjaro.org/gnome/23.1.3/manjaro-gnome-23.1.3-240113-linux66.iso"; ISO="manjaro.iso"; OS="l26" ;;
        *) return ;;
    esac

    # Verifica se ISO já existe
    ISO_PATH="$TEMP_DIR/$ISO"
    if [ ! -f "$ISO_PATH" ]; then
        echo "Baixando ISO (pode demorar)..."
        wget -q --show-progress "$URL" -O "$ISO_PATH"
    else
        echo "ISO já encontrada em cache."
    fi

    read -p "ID: " VMID
    read -p "Nome: " VMNAME
    
    qm create "$VMID" --name "$VMNAME" --memory 4096 --cores 4 --cpu host --net0 virtio,bridge="$DEFAULT_BRIDGE" --ostype l26
    
    # Configuração Gráfica
    qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "$DEFAULT_STORAGE:64,cache=writeback,discard=on"
    qm set "$VMID" --ide2 "$ISO_STORAGE:iso/$ISO,media=cdrom"
    qm set "$VMID" --vga virtio # VirtIO-GPU para melhor performance gráfica no instalador
    qm set "$VMID" --agent enabled=1
    qm set "$VMID" --tags "ISO,Desktop"

    configure_cpu_affinity "$VMID"

    echo -e "${GN}VM criada com ISO montada!${CL}"
    echo "Inicie a VM e use o Console (NoVNC) para instalar o sistema."
    read -p "Enter..."
}

# --- MENU PRINCIPAL ---

while true; do
    header
    echo "1) Linux Cloud-Init (Debian, Ubuntu, Fedora, Arch, Kali Std)"
    echo "2) Linux Desktop ISO (Mint, Manjaro, Kali Purple)"
    echo -e "${YW}3) Windows 11 Gamer (GPU Passthrough)${CL}"
    echo "4) Listar VMs"
    echo "5) Excluir VM"
    echo "0) Sair"
    echo ""
    read -p "Escolha: " OPTION

    case $OPTION in
        1) create_cloud_vm ;;
        2) create_iso_vm ;;
        3) create_gaming_vm ;;
        4) list_vms ;;
        5) delete_vm ;;
        0) exit 0 ;;
        *) echo "Opção inválida." ;;
    esac
done
