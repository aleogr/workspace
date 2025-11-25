#!/bin/bash
# ==============================================================================
# PROXMOX VM MANAGER - ALEOGR (v5.4 - Navigation Polish)
# ==============================================================================
# Gerenciamento de VMs.
# Melhorias: Navegação consistente ("0" para voltar/cancelar em tudo).
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
    echo -e "${YW}VM Manager v5.4 (Navigation)${CL}"
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
    echo "1) P-Cores (0-15)  -> Performance"
    echo "2) E-Cores (16-31) -> Background"
    echo "3) Manual          -> Definir lista"
    echo "4) Padrão          -> Automático (Reset)"
    echo "0) Pular (Manter Atual)"
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
        printf "${YW}%-6s | %-20s | %-10s | %-4s | %-8s | %-8s | %-35s${CL}\n" \
            "ID" "NOME" "STATUS" "CPU" "RAM" "TYPE" "TAGS"
        echo "--------------------------------------------------------------------------------------------------------"

        for vmid in $(qm list | awk 'NR>1 {print $1}' | sort -n); do
            CONF=$(qm config $vmid)
            NAME=$(echo "$CONF" | grep "^name:" | awk '{print $2}')
            STATUS=$(qm status $vmid | awk '{print $2}')
            CORES=$(echo "$CONF" | grep "^cores:" | awk '{print $2}')
            [ -z "$CORES" ] && CORES="1"
            MEM_MB=$(echo "$CONF" | grep "^memory:" | awk '{print $2}')
            if [ "$MEM_MB" -ge 1024 ]; then
                MEM=$(echo "scale=1; $MEM_MB/1024" | bc | awk '{print int($1+0.5)}')
                MEM="${MEM}GB"
            else
                MEM="${MEM_MB}MB"
            fi

            RAW_TAGS=$(echo "$CONF" | grep "^tags:" | cut -d: -f2 | tr -d ' ' | tr ',' ' ')
            # Ordenação Visual: Tipo > Arch > Family > Outros
            SORTED_TAGS=""
            for t in $RAW_TAGS; do if [[ "$t" == "vm" || "$t" == "container" ]]; then SORTED_TAGS="$SORTED_TAGS $t"; fi; done
            for t in $RAW_TAGS; do if [[ "$t" == "amd64" || "$t" == "arm64" ]]; then SORTED_TAGS="$SORTED_TAGS $t"; fi; done
            for t in $RAW_TAGS; do if [[ "$t" == "windows" || "$t" == "linux" ]]; then SORTED_TAGS="$SORTED_TAGS $t"; fi; done
            for t in $RAW_TAGS; do 
                if [[ "$t" != "vm" && "$t" != "container" && "$t" != "amd64" && "$t" != "arm64" && "$t" != "windows" && "$t" != "linux" ]]; then 
                    SORTED_TAGS="$SORTED_TAGS $t"
                fi
            done
            TAGS_DISPLAY=$(echo $SORTED_TAGS | tr ' ' ',')

            if echo "$CONF" | grep -q "hostpci0"; then DISPLAY="GPU"; else DISPLAY="Std"; fi
            if [ "$STATUS" == "running" ]; then S_COLOR=$GN; else S_COLOR=$RD; fi

            printf "%-6s | %-20s | ${S_COLOR}%-10s${CL} | %-4s | %-8s | %-8s | %-35s\n" \
                "$vmid" "${NAME:0:20}" "$STATUS" "$CORES" "$MEM" "$DISPLAY" "${TAGS_DISPLAY:0:35}"
        done
        echo "--------------------------------------------------------------------------------------------------------"
        echo ""
        echo -e "Digite o ${BL}ID${CL} para Ações."
        echo -e "Digite ${BL}r${CL} para Atualizar."
        echo -e "Digite ${BL}0${CL} para Voltar ao Menu Principal."
        echo ""
        read -p "> " ACTION

        if [ -z "$ACTION" ] || [ "$ACTION" == "0" ]; then return; fi
        if [ "$ACTION" == "r" ]; then continue; fi

        if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
            if ! qm status "$ACTION" >/dev/null 2>&1; then
                echo -e "${RD}VM $ACTION não encontrada.${CL}"; sleep 1; continue
            fi
            
            VM_NAME=$(qm config "$ACTION" | grep name | awk '{print $2}')
            CURR_STATUS=$(qm status $ACTION | awk '{print $2}')
            
            echo ""
            echo -e "${YW}--- GERENCIAR: $VM_NAME ($ACTION) ---${CL}"
            if [ "$CURR_STATUS" == "stopped" ]; then
                echo "1) Iniciar (Start)"
                echo "2) Excluir (Destroy)"
            else
                echo "1) Desligar (Shutdown)"
                echo "2) Forçar Parada (Stop)"
                echo "3) Reiniciar (Reboot)"
                echo "4) Excluir (Destroy)"
            fi
            echo "0) Voltar"
            read -p "Ação: " VM_ACT

            case $VM_ACT in
                1) if [ "$CURR_STATUS" == "stopped" ]; then qm start $ACTION; else qm shutdown $ACTION; fi ;;
                2) if [ "$CURR_STATUS" == "stopped" ]; then
                       read -p "Confirmar EXCLUSÃO (s/n)? " S; if [[ "$S" == "s" ]]; then qm destroy $ACTION --purge; fi
                   else qm stop $ACTION; fi ;;
                3) qm reboot $ACTION ;;
                4) read -p "Confirmar EXCLUSÃO FORÇADA (s/n)? " S; if [[ "$S" == "s" ]]; then qm stop $ACTION && qm destroy $ACTION --purge; fi ;;
                *) ;;
            esac
        fi
    done
}

# --- MÓDULO 1: WINDOWS ---
create_windows_vm() {
    echo -e "${GN}--- VM WINDOWS ---${CL}"
    echo "1) Windows 11 Standard"
    echo "2) Windows Server"
    echo -e "${YW}3) Windows Gamer (GPU)${CL}"
    echo "0) Voltar"
    read -p "Opção: " WIN_TYPE

    case $WIN_TYPE in
        1) ISO_SEARCH="win11"; GPU_MODE="off"; TAGS="vm,amd64,windows" ;;
        2) ISO_SEARCH="server"; GPU_MODE="off"; TAGS="vm,amd64,windows" ;;
        3) ISO_SEARCH="win11"; GPU_MODE="on"; TAGS="vm,amd64,windows" ;;
        0) return ;;
        *) echo "Opção inválida."; sleep 1; return ;;
    esac

    if [ "$GPU_MODE" == "on" ]; then
        TARGET_GPU=$(detect_gpu)
        if [ $? -ne 0 ]; then echo "${RD}Sem GPU.${CL}"; read -p "Enter..."; return; fi
    fi

    echo "Digite '0' no ID para cancelar."
    read -p "ID da VM: " VMID
    if [ "$VMID" == "0" ] || [ -z "$VMID" ]; then return; fi
    
    read -p "Nome da VM: " VMNAME
    read -p "Cores (4): " CORES; [ -z "$CORES" ] && CORES=4
    read -p "Memória MB (8192): " MEMORY; [ -z "$MEMORY" ] && MEMORY=8192
    read -p "Disco GB (64): " DISK_SIZE; [ -z "$DISK_SIZE" ] && DISK_SIZE=64

    WIN_ISO=$(find_iso "$ISO_SEARCH")
    if [ -z "$WIN_ISO" ]; then read -p "Caminho ISO Windows: " WIN_ISO; fi

    echo -e "${BL}Criando...${CL}"
    qm create "$VMID" --name "$VMNAME" --memory "$MEMORY" --cores "$CORES" \
        --machine q35 --bios ovmf --cpu host --numa 1 \
        --net0 virtio,bridge="$DEFAULT_BRIDGE" --ostype win11 --scsihw virtio-scsi-pci

    qm set "$VMID" --efidisk0 "$DEFAULT_STORAGE:0,efitype=4m" \
        --tpmstate0 "$DEFAULT_STORAGE:0,version=v2.0" \
        --scsi0 "$DEFAULT_STORAGE:${DISK_SIZE},cache=writeback,discard=on"

    VIRTIO_ISO=$(find_iso "virtio")
    [ -n "$WIN_ISO" ] && qm set "$VMID" --ide2 "$WIN_ISO,media=cdrom"
    [ -n "$VIRTIO_ISO" ] && qm set "$VMID" --ide0 "$VIRTIO_ISO,media=cdrom"
    
    qm set "$VMID" --boot order=ide2;scsi0
    qm set "$VMID" --agent enabled=1 --tags "$TAGS"

    if [ "$GPU_MODE" == "on" ]; then
        qm set "$VMID" --balloon 0
        qm set "$VMID" --hostpci0 "$TARGET_GPU,pcie=1,x-vga=1,rombar=1"
        qm set "$VMID" --vga none
        echo -e "${YW}Pinning P-Cores...${CL}"
        qm set "$VMID" --affinity "0-15"
    else
        qm set "$VMID" --balloon 1024 --vga std
        configure_cpu_affinity "$VMID"
    fi

    echo -e "${GN}Sucesso!${CL}"; read -p "Enter..."
}

# --- MÓDULO 2: LINUX CLOUD ---
create_cloud_vm() {
    echo -e "${GN}--- LINUX CLOUD-INIT ---${CL}"
    echo "1) Debian 13"
    echo "2) Ubuntu 24.04"
    echo "3) Kali Linux"
    echo "4) Fedora 41"
    echo "5) Arch Linux"
    echo "6) CentOS 9"
    echo "7) Rocky 9"
    echo "0) Voltar"
    read -p "Opção: " OPT

    TAGS="vm,amd64,linux"

    case $OPT in
        1) URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"; IMG="deb13.qcow2" ;;
        2) URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"; IMG="ubu24-04.img" ;;
        3) URL="https://kali.download/cloud-images/kali-rolling/kali-linux-rolling-cloud-generic-amd64.qcow2"; IMG="kali.qcow2" ;;
        4) URL="https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-Generic.x86_64-41-1.4.qcow2"; IMG="fedora.qcow2" ;;
        5) URL="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"; IMG="arch.qcow2" ;;
        6) URL="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"; IMG="centos9.qcow2" ;;
        7) URL="https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"; IMG="rocky9.qcow2" ;;
        0) return ;;
        *) echo "Inválido."; sleep 1; return ;;
    esac

    echo "Digite '0' no ID para cancelar."
    read -p "ID: " VMID
    if [ "$VMID" == "0" ] || [ -z "$VMID" ]; then return; fi

    read -p "Nome: " VMNAME
    read -p "Cores (2): " CORES; [ -z "$CORES" ] && CORES=2
    read -p "RAM MB (2048): " RAM; [ -z "$RAM" ] && RAM=2048

    echo "Baixando..."
    wget -q --show-progress "$URL" -O "$TEMP_DIR/$IMG"

    qm create "$VMID" --name "$VMNAME" --memory "$RAM" --cores "$CORES" --cpu host --net0 virtio,bridge="$DEFAULT_BRIDGE"
    qm importdisk "$VMID" "$TEMP_DIR/$IMG" "$DEFAULT_STORAGE"
    qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "$DEFAULT_STORAGE:vm-$VMID-disk-0,discard=on"
    qm set "$VMID" --ide2 "$DEFAULT_STORAGE:cloudinit" --boot c --bootdisk scsi0 --serial0 socket --vga serial0
    qm set "$VMID" --ciuser "$DEFAULT_USER" --ipconfig0 ip=dhcp
    qm set "$VMID" --tags "$TAGS"

    read -p "Espaço Adicional (GB) [32]: " ADD_GB; [ -z "$ADD_GB" ] && ADD_GB=32
    qm resize "$VMID" scsi0 "+${ADD_GB}G"
    rm "$TEMP_DIR/$IMG"

    configure_cpu_affinity "$VMID"
    echo -e "${GN}Sucesso!${CL}"; read -p "Enter..."
}

# --- MÓDULO 3: LINUX ISO ---
create_iso_vm() {
    echo -e "${GN}--- LINUX ISO ---${CL}"
    echo "1) Linux Mint 22"
    echo "2) Kali Purple"
    echo "3) Manjaro Gnome"
    echo "4) Gentoo Minimal"
    echo "0) Voltar"
    read -p "Opção: " OPT
    
    TAGS="vm,amd64,linux"

    case $OPT in
        1) URL="https://mirrors.edge.kernel.org/linuxmint/stable/22/linuxmint-22-cinnamon-64bit.iso"; ISO="mint22.iso" ;;
        2) URL="https://cdimage.kali.org/current/kali-linux-purple-installer-amd64.iso"; ISO="kali-purple.iso" ;;
        3) URL="https://download.manjaro.org/gnome/24.1.0/manjaro-gnome-24.1.0-linux610.iso"; ISO="manjaro.iso" ;;
        4) URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-install-amd64-minimal/install-amd64-minimal.iso"; ISO="gentoo.iso" ;;
        0) return ;;
        *) echo "Inválido."; sleep 1; return ;;
    esac

    if [ ! -f "$TEMP_DIR/$ISO" ]; then wget -q --show-progress "$URL" -O "$TEMP_DIR/$ISO"; fi

    echo "Digite '0' no ID para cancelar."
    read -p "ID: " VMID
    if [ "$VMID" == "0" ] || [ -z "$VMID" ]; then return; fi
    
    read -p "Nome: " VMNAME
    qm create "$VMID" --name "$VMNAME" --memory 4096 --cores 4 --cpu host --net0 virtio,bridge="$DEFAULT_BRIDGE" --ostype l26
    
    read -p "Disco (GB) [32]: " DSIZE; [ -z "$DSIZE" ] && DSIZE=32
    qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "$DEFAULT_STORAGE:${DSIZE},cache=writeback,discard=on"
    qm set "$VMID" --ide2 "$ISO_STORAGE:iso/$ISO,media=cdrom" --vga virtio --agent enabled=1
    qm set "$VMID" --boot order=ide2;scsi0
    qm set "$VMID" --tags "$TAGS"

    configure_cpu_affinity "$VMID"
    echo -e "${GN}Sucesso!${CL}"; read -p "Enter..."
}

# --- MENU DE CRIAÇÃO (SUBMENU) ---
submenu_create() {
    while true; do
        header
        echo -e "${YW}CRIAR NOVA VM:${CL}"
        echo "1) Windows (Desktop/Gamer)"
        echo "2) Linux Cloud-Init (Automático)"
        echo "3) Linux ISO (Manual)"
        echo "0) Voltar ao Menu Principal"
        echo ""
        read -p "Opção: " SOPT
        case $SOPT in
            1) create_windows_vm ;;
            2) create_cloud_vm ;;
            3) create_iso_vm ;;
            0) return ;;
            *) echo "Inválido." ; sleep 1 ;;
        esac
    done
}

# --- MENU PRINCIPAL ---
while true; do
    header
    echo -e "1) ${GN}Listar e Gerenciar VMs${CL}"
    echo -e "2) ${YW}Criar Nova VM${CL}"
    echo "0) Sair"
    echo ""
    read -p "Escolha: " MOPT

    case $MOPT in
        1) manage_vms ;;
        2) submenu_create ;;
        0) exit 0 ;;
        *) echo "Opção inválida." ; sleep 1 ;;
    esac
done
