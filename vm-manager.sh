#!/bin/bash
# ==============================================================================
# PROXMOX VM MANAGER - ALEOGR (v4.5 - Timeline Corrected)
# ==============================================================================
# Gerenciamento de VMs com versões atualizadas para o cenário de 2025.
# Debian 13 Stable, Ubuntu 25.10, etc.
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
    echo -e "${YW}VM Manager v4.5 (2025 Edition)${CL}"
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
        printf "${YW}%-5s | %-20s | %-10s | %-5s | %-8s | %-10s | %-12s | %-20s${CL}\n" "ID" "NOME" "STATUS" "CPU" "RAM" "DISCO" "DISPLAY" "TAGS"
        echo "----------------------------------------------------------------------------------------------------------------"

        for vmid in $(qm list | awk 'NR>1 {print $1}' | sort -n); do
            CONF=$(qm config $vmid)
            NAME=$(echo "$CONF" | grep "^name:" | awk '{print $2}')
            STATUS=$(qm status $vmid | awk '{print $2}')
            CORES=$(echo "$CONF" | grep "^cores:" | awk '{print $2}')
            [ -z "$CORES" ] && CORES="1"
            MEM=$(echo "$CONF" | grep "^memory:" | awk '{print $2}')
            TAGS=$(echo "$CONF" | grep "^tags:" | cut -d: -f2 | tr -d ' ')
            
            DISK_INFO=$(echo "$CONF" | grep -E "^(scsi0|ide0|virtio0):" | head -n 1)
            DISK_SIZE=$(echo "$DISK_INFO" | grep -o "size=[^,]*" | cut -d= -f2)
            [ -z "$DISK_SIZE" ] && DISK_SIZE="-"

            if echo "$CONF" | grep -q "hostpci0"; then DISPLAY="GPU-Pass"; else
                DISPLAY=$(echo "$CONF" | grep "^vga:" | awk '{print $2}')
                [ -z "$DISPLAY" ] && DISPLAY="Std"
            fi

            if [ "$STATUS" == "running" ]; then S_COLOR=$GN; else S_COLOR=$RD; fi

            printf "%-5s | %-20s | ${S_COLOR}%-10s${CL} | %-5s | %-8s | %-10s | %-12s | %-20s\n" \
                "$vmid" "${NAME:0:20}" "$STATUS" "$CORES" "${MEM}MB" "$DISK_SIZE" "$DISPLAY" "${TAGS:0:20}"
        done
        echo "----------------------------------------------------------------------------------------------------------------"
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
    
    qm set "$VMID" --hostpci0 "$TARGET_GPU,pcie=1,x-vga=1,rombar=1" --vga none --agent enabled=1 --tags "vm,windows,amd64,gpu"
    
    echo -e "${GN}VM Windows Gamer criada!${CL}"
    read -p "Enter..."
}

# --- MÓDULO 2: LINUX CLOUD (AUTO-INSTALL) ---
create_cloud_vm() {
    echo -e "${GN}--- LINUX CLOUD-INIT (2025 Editions) ---${CL}"
    echo "1) Debian 13 Trixie (Stable)"
    echo "2) Debian 12 Bookworm (OldStable)"
    echo "3) Ubuntu 24.04 LTS (Noble)"
    echo "4) Ubuntu 25.10 (Latest)"
    echo "5) Kali Linux (Rolling)"
    echo "6) Fedora 43 Cloud"
    echo "7) Arch Linux Cloud"
    echo "8) CentOS Stream 9"
    echo "9) Rocky Linux 9"
    echo "0) Voltar"
    read -p "Opção: " OPT

    case $OPT in
        # URL ajustada para a pasta 'latest' do trixie, assumindo release stable
        1) URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"; IMG="deb13.qcow2"; TAGS="vm,linux,debian,amd64" ;;
        2) URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"; IMG="deb12.qcow2"; TAGS="vm,linux,debian,amd64" ;;
        3) URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"; IMG="ubu24-04.img"; TAGS="vm,linux,ubuntu,amd64" ;;
        4) URL="https://cloud-images.ubuntu.com/releases/25.10/release/ubuntu-25.10-server-cloudimg-amd64.img"; IMG="ubu25-10.img"; TAGS="vm,linux,ubuntu,amd64" ;;
        5) URL="https://kali.download/cloud-images/kali-rolling/kali-linux-rolling-cloud-generic-amd64.qcow2"; IMG="kali.qcow2"; TAGS="vm,linux,kali,amd64" ;;
        6) URL="https://download.fedoraproject.org/pub/fedora/linux/releases/43/Cloud/x86_64/images/Fedora-Cloud-Base-Generic.x86_64-43-1.2.qcow2"; IMG="fedora.qcow2"; TAGS="vm,linux,fedora,amd64" ;;
        7) URL="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"; IMG="arch.qcow2"; TAGS="vm,linux,arch,amd64" ;;
        8) URL="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"; IMG="centos9.qcow2"; TAGS="vm,linux,centos,amd64" ;;
        9) URL="https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"; IMG="rocky9.qcow2"; TAGS="vm,linux,rocky,amd64" ;;
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
    qm set "$VMID" --tags "$TAGS"

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
    echo "2) Kali Linux PURPLE (2025.x)"
    echo "3) Manjaro Gnome (Latest)"
    echo "4) Gentoo Minimal (Latest)"
    echo "0) Voltar"
    read -p "Opção: " OPT

    case $OPT in
        1) URL="https://mirrors.edge.kernel.org/linuxmint/stable/22/linuxmint-22-cinnamon-64bit.iso"; ISO="mint22.iso"; TAGS="vm,linux,mint,amd64" ;;
        2) URL="https://cdimage.kali.org/current/kali-linux-purple-installer-amd64.iso"; ISO="kali-purple.iso"; TAGS="vm,linux,kali,amd64" ;;
        3) URL="https://download.manjaro.org/gnome/24.1.0/manjaro-gnome-24.1.0-linux610.iso"; ISO="manjaro.iso"; TAGS="vm,linux,manjaro,amd64" ;;
        4) URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-install-amd64-minimal/install-amd64-minimal.iso"; ISO="gentoo.iso"; TAGS="vm,linux,gentoo,amd64" ;;
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
    qm set "$VMID" --tags "$TAGS"

    configure_cpu_affinity "$VMID"

    echo -e "${GN}VM criada com ISO montada!${CL}"
    read -p "Enter..."
}

# --- MENU PRINCIPAL ---

while true; do
    header
    echo "1) Linux Cloud-Init (Debian 13, Ubuntu 25, etc)"
    echo "2) Linux Manual ISO (Mint, Manjaro, Gentoo)"
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
