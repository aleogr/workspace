#!/bin/bash
# ==============================================================================
# PROXMOX VM MANAGER - ALEOGR (v5.3 - Dashboard Pro)
# ==============================================================================
# - Menu organizado (Submenus).
# - Dashboard com ações: Start, Shutdown, Stop, Delete.
# - Ordenação de Tags Rigorosa: VM > Arch > Family > Others.
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
    echo -e "${YW}VM Manager v5.3 (Dashboard Pro)${CL}"
    echo ""
}

# --- FUNÇÕES AUXILIARES ---

detect_gpu() {
    GPU_RAW=$(lspci -nn | grep -i "NVIDIA" | grep -i "VGA" | head -n 1 | awk '{print $1}')
    if [ -z "$GPU_RAW" ]; then return 1; else
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
    echo "4) Padrão          -> Automático"
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

# --- FUNÇÃO: ORDENAR TAGS ---
sort_tags() {
    # Recebe string "tag1,tag2,tag3"
    local RAW_TAGS=$(echo "$1" | tr ',' ' ')
    local TYPE=""
    local ARCH=""
    local FAMILY=""
    local OTHERS=""

    for t in $RAW_TAGS; do
        case "$t" in
            vm|container) TYPE="$t" ;;
            amd64|arm64|riscv64) ARCH="$t" ;;
            linux|windows|bsd|macos) FAMILY="$t" ;;
            *) OTHERS="$OTHERS $t" ;;
        esac
    done

    # Monta na ordem estrita: TIPO > ARCH > FAMILY > OUTROS
    # O 'tr -s' remove espaços duplos
    echo "$TYPE $ARCH $FAMILY $OTHERS" | tr -s ' ' | tr ' ' ','
}

# --- DASHBOARD INTERATIVO ---
manage_vms() {
    while true; do
        header
        echo -e "${GN}--- DASHBOARD DE VMS ---${CL}"
        printf "${YW}%-6s | %-20s | %-10s | %-4s | %-8s | %-8s | %-35s${CL}\n" \
            "ID" "NOME" "STATUS" "CPU" "RAM" "TYPE" "TAGS (Sorted)"
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

            # Ordenação de Tags
            RAW_TAGS=$(echo "$CONF" | grep "^tags:" | cut -d: -f2 | tr -d ' ')
            SORTED_TAGS=$(sort_tags "$RAW_TAGS")

            # Display Type
            if echo "$CONF" | grep -q "hostpci0"; then DISPLAY="GPU"; else DISPLAY="Std"; fi

            if [ "$STATUS" == "running" ]; then S_COLOR=$GN; else S_COLOR=$RD; fi

            printf "%-6s | %-20s | ${S_COLOR}%-10s${CL} | %-4s | %-8s | %-8s | %-35s\n" \
                "$vmid" "${NAME:0:20}" "$STATUS" "$CORES" "$MEM" "$DISPLAY" "${SORTED_TAGS:0:35}"
        done
        echo "--------------------------------------------------------------------------------------------------------"
        echo ""
        echo -e "Digite o ${BL}ID${CL} da VM para abrir o menu de ações."
        echo -e "Digite ${BL}r${CL} para atualizar."
        echo -e "Digite ${BL}0${CL} ou Enter para voltar."
        echo ""
        read -p "> " ACTION

        if [ -z "$ACTION" ] || [ "$ACTION" == "0" ]; then return; fi
        if [ "$ACTION" == "r" ]; then continue; fi

        # Menu de Ações da VM
        if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
            if ! qm status "$ACTION" >/dev/null 2>&1; then
                echo -e "${RD}VM $ACTION não encontrada.${CL}"; sleep 1; continue
            fi
            
            CURR_STATUS=$(qm status $ACTION | awk '{print $2}')
            VM_NAME=$(qm config $ACTION | grep name | awk '{print $2}')
            
            echo ""
            echo -e "${YW}--- GERENCIAR VM: $ACTION ($VM_NAME) ---${CL}"
            echo -e "Status Atual: ${S_COLOR}$CURR_STATUS${CL}"
            echo ""
            
            if [ "$CURR_STATUS" == "stopped" ]; then
                echo "1) Iniciar (Start)"
                echo "2) Excluir (Delete - Purge)"
            else
                echo "1) Desligar Suave (Shutdown ACPI)"
                echo "2) Forçar Parada (Stop - Kill)"
                echo "3) Reiniciar (Reboot)"
                echo "4) Excluir (Delete - Purge)"
            fi
            echo "0) Cancelar"
            echo ""
            read -p "Ação: " VM_ACT

            case $VM_ACT in
                1) 
                    if [ "$CURR_STATUS" == "stopped" ]; then
                        echo "Iniciando..." && qm start $ACTION
                    else
                        echo "Enviando sinal de desligamento..." && qm shutdown $ACTION
                    fi
                    ;;
                2)
                    if [ "$CURR_STATUS" == "stopped" ]; then
                        # Lógica de Delete (Stop)
                        echo -e "${RD}VOCÊ VAI DELETAR A VM $ACTION PERMANENTEMENTE!${CL}"
                        read -p "Digite 'CONFIRMAR': " SURE
                        if [ "$SURE" == "CONFIRMAR" ]; then qm destroy $ACTION --purge; echo "Deletada."; sleep 1; fi
                    else
                        # Lógica de Stop (Running)
                        echo "Matando processo da VM..." && qm stop $ACTION
                    fi
                    ;;
                3) 
                    if [ "$CURR_STATUS" == "running" ]; then echo "Reiniciando..." && qm reboot $ACTION; fi 
                    ;;
                4)
                    # Delete forçado (Running)
                    echo -e "${RD}VOCÊ VAI DELETAR A VM $ACTION PERMANENTEMENTE!${CL}"
                    read -p "Digite 'CONFIRMAR': " SURE
                    if [ "$SURE" == "CONFIRMAR" ]; then
                        qm stop $ACTION >/dev/null 2>&1
                        qm destroy $ACTION --purge
                        echo "Deletada."
                        sleep 1
                    fi
                    ;;
                *) ;;
            esac
            sleep 1
        fi
    done
}

# --- MÓDULOS DE CRIAÇÃO (Refatorados com Tags Fixas) ---

create_gaming_vm() {
    echo -e "${GN}--- WINDOWS GAMER ---${CL}"
    TARGET_GPU=$(detect_gpu)
    if [ $? -ne 0 ]; then echo "${RD}Sem GPU.${CL}"; read -p "Enter..."; return; fi

    read -p "ID: " VMID
    read -p "Nome: " VMNAME
    WIN_ISO=$(find_iso "win11"); VIRTIO_ISO=$(find_iso "virtio")
    if [ -z "$WIN_ISO" ]; then read -p "Caminho ISO Windows: " WIN_ISO; fi

    qm create "$VMID" --name "$VMNAME" --memory 32768 --cores 8 \
        --machine q35 --bios ovmf --cpu host --numa 1 --net0 virtio,bridge="$DEFAULT_BRIDGE" --ostype win11 --scsihw virtio-scsi-pci

    read -p "Disco (GB) [100]: " DSIZE; [ -z "$DSIZE" ] && DSIZE=100
    qm set "$VMID" --balloon 0 --efidisk0 "$DEFAULT_STORAGE:0,efitype=4m" --tpmstate0 "$DEFAULT_STORAGE:0,version=v2.0" \
        --scsi0 "$DEFAULT_STORAGE:${DSIZE},cache=writeback,discard=on"
    
    [ -n "$WIN_ISO" ] && qm set "$VMID" --ide2 "$WIN_ISO,media=cdrom"
    [ -n "$VIRTIO_ISO" ] && qm set "$VMID" --ide0 "$VIRTIO_ISO,media=cdrom"

    qm set "$VMID" --boot order=ide2;scsi0
    configure_cpu_affinity "$VMID"
    
    # Tags Estritas
    qm set "$VMID" --hostpci0 "$TARGET_GPU,pcie=1,x-vga=1,rombar=1" --vga none --agent enabled=1 --tags "vm,amd64,windows"
    echo -e "${GN}VM Criada!${CL}"; read -p "Enter..."
}

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

    TAGS="vm,amd64,linux" # Padrão

    case $OPT in
        1) URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"; IMG="deb13.qcow2" ;;
        2) URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"; IMG="ubu24.img" ;;
        3) URL="https://kali.download/cloud-images/kali-rolling/kali-linux-rolling-cloud-generic-amd64.qcow2"; IMG="kali.qcow2" ;;
        4) URL="https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-Generic.x86_64-41-1.4.qcow2"; IMG="fedora.qcow2" ;;
        5) URL="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"; IMG="arch.qcow2" ;;
        6) URL="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"; IMG="centos9.qcow2" ;;
        7) URL="https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"; IMG="rocky9.qcow2" ;;
        *) return ;;
    esac

    read -p "ID: " VMID
    read -p "Nome: " VMNAME
    
    wget -q --show-progress "$URL" -O "$TEMP_DIR/$IMG"
    qm create "$VMID" --name "$VMNAME" --memory 2048 --cores 2 --cpu host --net0 virtio,bridge="$DEFAULT_BRIDGE"
    qm importdisk "$VMID" "$TEMP_DIR/$IMG" "$DEFAULT_STORAGE"
    qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "$DEFAULT_STORAGE:vm-$VMID-disk-0,discard=on" --ide2 "$DEFAULT_STORAGE:cloudinit" --boot c --bootdisk scsi0 --serial0 socket --vga serial0 --ciuser "$DEFAULT_USER" --ipconfig0 ip=dhcp
    qm set "$VMID" --tags "$TAGS"

    read -p "Espaço Adicional (GB) [32]: " ADD_GB; [ -z "$ADD_GB" ] && ADD_GB=32
    qm resize "$VMID" scsi0 "+${ADD_GB}G"
    rm "$TEMP_DIR/$IMG"

    configure_cpu_affinity "$VMID"
    echo -e "${GN}VM Criada!${CL}"; read -p "Enter..."
}

create_iso_vm() {
    echo -e "${GN}--- LINUX MANUAL ISO ---${CL}"
    echo "1) Linux Mint"
    echo "2) Kali Purple"
    echo "3) Manjaro"
    echo "4) Gentoo"
    echo "0) Voltar"
    read -p "Opção: " OPT

    TAGS="vm,amd64,linux"

    case $OPT in
        1) URL="https://mirrors.edge.kernel.org/linuxmint/stable/22/linuxmint-22-cinnamon-64bit.iso"; ISO="mint.iso" ;;
        2) URL="https://cdimage.kali.org/current/kali-linux-purple-installer-amd64.iso"; ISO="kali.iso" ;;
        3) URL="https://download.manjaro.org/gnome/24.0.6/manjaro-gnome-24.0.6-240729-linux69.iso"; ISO="manjaro.iso" ;;
        4) URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-install-amd64-minimal/install-amd64-minimal.iso"; ISO="gentoo.iso" ;;
        *) return ;;
    esac

    if [ ! -f "$TEMP_DIR/$ISO" ]; then wget -q --show-progress "$URL" -O "$TEMP_DIR/$ISO"; fi

    read -p "ID: " VMID
    read -p "Nome: " VMNAME
    qm create "$VMID" --name "$VMNAME" --memory 4096 --cores 4 --cpu host --net0 virtio,bridge="$DEFAULT_BRIDGE" --ostype l26
    
    read -p "Disco (GB) [32]: " DSIZE; [ -z "$DSIZE" ] && DSIZE=32
    qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "$DEFAULT_STORAGE:${DSIZE},cache=writeback,discard=on"
    qm set "$VMID" --ide2 "$ISO_STORAGE:iso/$ISO,media=cdrom" --vga virtio --agent enabled=1 --boot order=ide2;scsi0
    qm set "$VMID" --tags "$TAGS"

    configure_cpu_affinity "$VMID"
    echo -e "${GN}VM Criada!${CL}"; read -p "Enter..."
}

create_windows_general() {
    echo -e "${GN}--- WINDOWS GERAL (Sem GPU) ---${CL}"
    echo "1) Windows 11 Desktop"
    echo "2) Windows Server"
    read -p "Opção: " WOPT
    
    case $WOPT in
        1) ISO="win11"; TAGS="vm,amd64,windows" ;;
        2) ISO="server"; TAGS="vm,amd64,windows" ;;
        *) return ;;
    esac
    
    read -p "ID: " VMID
    read -p "Nome: " VMNAME
    WIN_ISO=$(find_iso "$ISO"); VIRTIO_ISO=$(find_iso "virtio")

    qm create "$VMID" --name "$VMNAME" --memory 8192 --cores 4 --machine q35 --bios ovmf --cpu host --net0 virtio,bridge="$DEFAULT_BRIDGE" --ostype win11 --scsihw virtio-scsi-pci
    qm set "$VMID" --efidisk0 "$DEFAULT_STORAGE:0,efitype=4m" --tpmstate0 "$DEFAULT_STORAGE:0,version=v2.0"
    
    read -p "Disco (GB) [64]: " DSIZE; [ -z "$DSIZE" ] && DSIZE=64
    qm set "$VMID" --scsi0 "$DEFAULT_STORAGE:${DSIZE},cache=writeback,discard=on"
    
    [ -n "$WIN_ISO" ] && qm set "$VMID" --ide2 "$WIN_ISO,media=cdrom"
    [ -n "$VIRTIO_ISO" ] && qm set "$VMID" --ide0 "$VIRTIO_ISO,media=cdrom"
    
    qm set "$VMID" --boot order=ide2;scsi0 --balloon 1024 --vga std --agent enabled=1 --tags "$TAGS"
    
    configure_cpu_affinity "$VMID"
    echo -e "${GN}VM Criada!${CL}"; read -p "Enter..."
}

# --- MENU DE CRIAÇÃO (SUBMENU) ---
submenu_create_vm() {
    while true; do
        clear
        echo -e "${BL}--- CRIAR NOVA VM ---${CL}"
        echo "1) Windows Gamer (GPU Passthrough)"
        echo "2) Windows Geral (Desktop/Server)"
        echo "3) Linux Cloud-Init (Automático)"
        echo "4) Linux Manual (ISO)"
        echo "0) Voltar"
        echo ""
        read -p "Opção: " SOPT
        
        case $SOPT in
            1) create_gaming_vm ;;
            2) create_windows_general ;;
            3) create_cloud_vm ;;
            4) create_iso_vm ;;
            0) return ;;
            *) echo "Opção inválida." ;;
        esac
    done
}

# --- MENU PRINCIPAL ---
while true; do
    header
    echo -e "1) ${GN}Listar e Gerenciar VMs (Dashboard)${CL}"
    echo -e "2) ${YW}Criar Nova VM...${CL}"
    echo "0) Sair"
    echo ""
    read -p "Escolha: " OPTION

    case $OPTION in
        1) manage_vms ;;
        2) submenu_create_vm ;;
        0) exit 0 ;;
        *) echo "Opção inválida." ;;
    esac
done
