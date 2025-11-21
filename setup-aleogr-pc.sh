#!/bin/bash
# ==============================================================================
# MASTER SETUP SCRIPT - ALEOGR-PC (Versão Final Gold)
# ==============================================================================
# Automação completa para Workstation Proxmox com Passthrough e ZFS.
# ==============================================================================

# --- VARIÁVEIS GLOBAIS (EDITE AQUI) ---
# ------------------------------------------------------------------------------
NEW_USER="aleogr"
DEBIAN_CODENAME="trixie"

# Seleção automática do disco baseada no ambiente (Real vs VM)
if systemd-detect-virt | grep -q "none"; then
    # Hardware Real (WD SN850X)
    DISK_DEVICE="/dev/disk/by-id/nvme-WD_BLACK_SN850X_2000GB_222503A00551"
else
    # Ambiente Virtual (Teste)
    DISK_DEVICE="/dev/sdb"
fi

POOL_NAME="tank"
STORAGE_ID_VM="VM-Storage"
DATASTORE_PBS="Backup-PBS"
ZFS_ARC_GB=8
CPU_GOVERNOR="powersave" # 'powersave' = Balanceado (Recomendado para Intel moderno)
ENABLE_ENCRYPTION="yes"  # "yes" ou "no"
# ------------------------------------------------------------------------------

# Cores
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")

# Função de Cabeçalho com Hardware Info
header() {
    clear
    echo -e "${BL}
   __   __   ____  __   ___  ____
  / _\ (  ) (  __)/  \ / __)(  _ \\
 /    \/ (_/\) _)(  O ( (_ \ )   /
 \_/\_/\____/(____)\__/ \___/(__\_)
    ${CL}"
    echo -e "${YW}HARDWARE VALIDADO (Target):${CL}"
    echo -e " • MB:  ${GN}ASUS ROG MAXIMUS Z790 HERO${CL}"
    echo -e " • CPU: ${GN}Intel Core i9-13900K${CL}"
    echo -e " • GPU: ${GN}NVIDIA GeForce RTX 3090 Ti${CL}"
    echo -e " • RAM: ${GN}64GB DDR5${CL}"
    echo -e " • SSD: ${GN}WD Black SN850X 2TB (Data)${CL} + NVMe 512GB (OS)"
    echo ""
    
    # Aviso se estiver em VM
    if ! systemd-detect-virt | grep -q "none"; then
        echo -e "${RD}[!] AMBIENTE VIRTUAL DETECTADO ($(systemd-detect-virt))${CL}"
        echo -e "${RD}[!] A Etapa 03 (Hardware Tune) será bloqueada.${CL}"
        echo ""
    fi
}

# Verifica Root
if [ "$EUID" -ne 0 ]; then echo "Por favor, rode como root"; exit 1; fi

# ==============================================================================
# MÓDULOS DE EXECUÇÃO
# ==============================================================================

step_01_system() {
    echo -e "${GN}>>> ETAPA 01: Sistema Base & Repositórios${CL}"
    
    mkdir -p /etc/apt/sources.list.d/backup_old
    mv /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/backup_old/ 2>/dev/null || true
    mv /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/backup_old/ 2>/dev/null || true
    
    if [ -f /etc/apt/sources.list ]; then
        echo "# Movido para debian.sources" > /etc/apt/sources.list
    fi

    cat <<EOF > /etc/apt/sources.list.d/debian.sources
Types: deb
URIs: http://deb.debian.org/debian
Suites: $DEBIAN_CODENAME $DEBIAN_CODENAME-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: $DEBIAN_CODENAME-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

    cat <<EOF > /etc/apt/sources.list.d/pve-no-subscription.sources
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: $DEBIAN_CODENAME
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-release-$DEBIAN_CODENAME.gpg

Types: deb
URIs: http://download.proxmox.com/debian/pbs
Suites: $DEBIAN_CODENAME
Components: pbs-no-subscription
Signed-By: /usr/share/keyrings/proxmox-release-$DEBIAN_CODENAME.gpg

Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: $DEBIAN_CODENAME
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-release-$DEBIAN_CODENAME.gpg
EOF

    echo "Atualizando sistema..."
    apt update && apt dist-upgrade -y
    
    echo "Instalando ferramentas..."
    apt install -y intel-microcode build-essential pve-headers vim htop btop curl git fastfetch ethtool net-tools

    if [ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]; then
        sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid subscription'\),)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
        systemctl restart pveproxy.service
        echo -e "${BL}[INFO] Aviso de Assinatura Removido.${CL}"
    fi

    apt autoremove -y && apt clean
    echo -e "${GN}✅ Etapa 01 Concluída.${CL}"
    read -p "Pressione Enter para voltar ao menu..."
}

step_02_gui() {
    echo -e "${GN}>>> ETAPA 02: Desktop GUI (Kiosk)${CL}"
    
    echo "Defina a senha para o usuário Linux ($NEW_USER):"
    read -s PASSWORD
    echo "Confirme:"
    read -s PASSWORD_CONFIRM
    
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then echo "${RD}Senhas não conferem!${CL}"; read -p "Enter..."; return; fi

    apt install -y xfce4 xfce4-goodies lightdm chromium sudo xorg xserver-xorg-video-all xserver-xorg-input-all --no-install-recommends

    if id "$NEW_USER" &>/dev/null; then
        # printf garante que senhas com hífen (-) não sejam interpretadas como flags
        printf "%s:%s\n" "$NEW_USER" "$PASSWORD" | chpasswd
    else
        useradd -m -s /bin/bash "$NEW_USER"
        printf "%s:%s\n" "$NEW_USER" "$PASSWORD" | chpasswd
        usermod -aG sudo "$NEW_USER"
    fi

    AUTOSTART_DIR="/home/$NEW_USER/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"

    cat <<EOF > "$AUTOSTART_DIR/proxmox-ui.desktop"
[Desktop Entry]
Type=Application
Name=Proxmox Kiosk
Exec=chromium --kiosk --no-sandbox --ignore-certificate-errors https://localhost:8006 https://localhost:8007
StartupNotify=false
Terminal=false
EOF

    chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.config"
    systemctl enable lightdm
    
    echo -e "${GN}✅ Etapa 02 Concluída.${CL}"
    echo -e "${YW}Nota: A interface gráfica iniciará no próximo Reboot.${CL}"
    read -p "Pressione Enter para voltar ao menu..."
}

step_03_hardware() {
    # Proteção contra execução em VM
    if ! systemd-detect-virt | grep -q "none"; then
        echo -e "${RD}ERRO: Esta etapa é exclusiva para Hardware Real (Bare Metal).${CL}"
        echo -e "Detectado ambiente virtual: $(systemd-detect-virt)"
        echo "Pressione Enter para voltar..."
        read
        return
    fi

    echo -e "${GN}>>> ETAPA 03: Hardware Tune (i9 + GPU)${CL}"
    
    ZFS_BYTES=$(($ZFS_ARC_GB * 1024 * 1024 * 1024))
    cp /etc/kernel/cmdline /etc/kernel/cmdline.bak
    
    CMDLINE="intel_iommu=on iommu=pt pci=noaer nvme_core.default_ps_max_latency_us=0 split_lock_detect=off video=efifb:off video=vesafb:off video=simplefb:off initcall_blacklist=sysfb_init"
    
    echo "root=ZFS=rpool/ROOT/pve-1 boot=zfs $CMDLINE" > /etc/kernel/cmdline
    proxmox-boot-tool refresh

    apt install -y cpufrequtils
    echo "GOVERNOR=\"$CPU_GOVERNOR\"" > /etc/default/cpufrequtils
    systemctl disable ondemand --now > /dev/null 2>&1 || true
    systemctl restart cpufrequtils

    echo "options kvm ignore_msrs=1 report_ignored_msrs=0" > /etc/modprobe.d/kvm.conf
    echo "options zfs zfs_arc_max=$ZFS_BYTES" > /etc/modprobe.d/zfs.conf

    update-pciids > /dev/null 2>&1 || true
    GPU_IDS=$(lspci -nn | grep -i nvidia | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}(?=\])' | tr '\n' ',' | sed 's/,$//')

    if [ -n "$GPU_IDS" ]; then
        echo "GPU Detectada: $GPU_IDS"
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
    else
        echo "${YW}[AVISO] GPU Nvidia não encontrada.${CL}"
    fi

    update-initramfs -u -k all
    echo -e "${GN}✅ Etapa 03 Concluída. REBOOT É CRUCIAL APÓS ESTA ETAPA!${CL}"
    read -p "Pressione Enter para voltar ao menu..."
}

step_04_storage() {
    echo -e "${GN}>>> ETAPA 04: Storage ZFS ($DISK_DEVICE)${CL}"
    
    if zpool list -o name -H | grep -q "^$POOL_NAME$"; then
        echo -e "${RD}ERRO CRÍTICO: O Pool ZFS '$POOL_NAME' JÁ EXISTE!${CL}"
        echo "Operação abortada para proteger dados."
        read -p "Enter..."
        return
    fi

    if [ ! -b "$DISK_DEVICE" ]; then echo "${RD}Erro: Disco $DISK_DEVICE não encontrado!${CL}"; read -p "Enter..." ; return; fi
    
    echo -e "${RD}!!! CUIDADO: ISSO VAI FORMATAR O DISCO DE 2TB !!!${CL}"
    echo -e "Recomendação: Só execute se já tiver reiniciado após a Etapa 03."
    echo "Digite 'CONFIRMAR' para continuar:"
    read -r INPUT
    if [ "$INPUT" != "CONFIRMAR" ]; then return; fi

    sgdisk --zap-all "$DISK_DEVICE" > /dev/null
    wipefs -a "$DISK_DEVICE" > /dev/null

    ZPOOL_ARGS="-f -o ashift=12 -o autotrim=on -O compression=lz4 -O atime=off -O acltype=posixacl -O xattr=sa"
    
    if [ "$ENABLE_ENCRYPTION" == "yes" ]; then
        echo -e "${YW}Defina a SENHA DO ZFS (PIN + YubiKey):${CL}"
        ZPOOL_ARGS="$ZPOOL_ARGS -O encryption=aes-256-gcm -O keyformat=passphrase -O keylocation=prompt"
    fi

    if zpool create $ZPOOL_ARGS "$POOL_NAME" "$DISK_DEVICE"; then
        echo "[OK] Pool criado."
    else
        echo "${RD}Falha ao criar o Pool. Verifique os logs.${CL}"
        read -p "Enter..."
        return
    fi

    zfs create "$POOL_NAME/vms"
    zfs create "$POOL_NAME/backups"
    
    if ! pvesm status | grep -q "$STORAGE_ID_VM"; then
        pvesm add zfspool "$STORAGE_ID_VM" --pool "$POOL_NAME/vms" --content images,rootdir --sparse 1
    fi

    echo -e "${GN}✅ Etapa 04 Concluída.${CL}"
    read -p "Pressione Enter para voltar ao menu..."
}

step_05_polish() {
    echo -e "${GN}>>> ETAPA 05: Ajuste de Memória (Swap)${CL}"
    CONFIG_FILE="/etc/sysctl.d/99-pve-swappiness.conf"
    echo "# Configuração customizada para Proxmox ZFS" > "$CONFIG_FILE"
    echo "vm.swappiness=10" >> "$CONFIG_FILE"
    sysctl --system > /dev/null
    echo -e "${GN}✅ Etapa 05 Concluída.${CL}"
    sleep 1
}

step_06_pbs() {
    echo -e "${GN}>>> ETAPA 06: Instalação PBS Local${CL}"
    apt install -y proxmox-backup-server proxmox-backup-client
    
    ZFS_PATH="/$POOL_NAME/backups"
    if [ -d "$ZFS_PATH" ]; then
        chown -R backup:backup $ZFS_PATH
        chmod 700 $ZFS_PATH
    else
        echo "${RD}Aviso: Pasta $ZFS_PATH não encontrada. Rode a Etapa 04 antes.${CL}"
        read -p "Enter..."
        return
    fi

    if ! proxmox-backup-manager datastore list | grep -q "$DATASTORE_PBS"; then
        proxmox-backup-manager datastore create $DATASTORE_PBS $ZFS_PATH
    fi

    FINGERPRINT=$(proxmox-backup-manager cert info | grep "Fingerprint" | awk '{print $NF}')
    
    echo "Digite a senha do ROOT do Linux para conectar o PVE ao PBS:"
    read -s PBS_PASSWORD

    if ! pvesm status | grep -q "$DATASTORE_PBS"; then
        # Usamos printf para passar a senha de forma segura se ela tiver caracteres especiais
        pvesm add pbs "$DATASTORE_PBS" \
            --server 127.0.0.1 \
            --datastore "$DATASTORE_PBS" \
            --fingerprint "$FINGERPRINT" \
            --username "root@pam" \
            --password "$PBS_PASSWORD" \
            --content backup
    fi
    echo -e "${GN}✅ Etapa 06 Concluída.${CL}"
    read -p "Pressione Enter para voltar ao menu..."
}

step_07_boot_unlock() {
    echo -e "${GN}>>> ETAPA 07: Serviço de Desbloqueio no Boot${CL}"
    SERVICE_FILE="/etc/systemd/system/zfs-load-key.service"
    
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Load ZFS encryption keys
DefaultDependencies=no
Before=zfs-mount.service
After=zfs-import.target
Requires=zfs-import.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/zfs load-key -a
StandardInput=tty-force

[Install]
WantedBy=zfs-mount.service
EOF

    systemctl daemon-reload
    systemctl enable zfs-load-key
    echo -e "${GN}✅ Etapa 07 Concluída.${CL}"
    read -p "Pressione Enter para voltar ao menu..."
}

step_08_pvescripts() {
    echo -e "${GN}>>> ETAPA 08: PVEScriptsLocal (Gerenciador de Scripts)${CL}"
    echo -e "Isso irá baixar e executar o instalador oficial do PVEScriptsLocal LXC."
    echo -e "O script original é mantido pela comunidade."
    echo ""
    echo "Deseja prosseguir? (s/n)"
    read -r CONFIRM
    if [[ "$CONFIRM" =~ ^[Ss]$ ]]; then
        # Executa o instalador oficial direto do repositório da comunidade
        bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/pvescriptslocal.sh)"
        echo -e "${GN}✅ Instalação do PVEScriptsLocal finalizada.${CL}"
    else
        echo "Operação cancelada."
    fi
    read -p "Pressione Enter para voltar ao menu..."
}

# ==============================================================================
# LOOP DO MENU PRINCIPAL
# ==============================================================================

while true; do
    header
    echo -e "${YW}Selecione uma etapa para executar:${CL}"
    echo "1) [Sistema]  Base, Repositórios e Microcode"
    echo "2) [Desktop]  GUI XFCE e Kiosk Mode"
    
    # Mostra a opção 3 em vermelho/bloqueado se for VM
    if systemd-detect-virt | grep -q "none"; then
        echo "3) [Hardware] Kernel, IOMMU, GPU e ZFS RAM"
    else
        echo -e "${RD}3) [Hardware] (Bloqueado em VM)${CL}"
    fi
    
    echo "4) [Storage]  Formatar 2TB, ZFS e Criptografia"
    echo "5) [Polish]   Ajuste de Swap"
    echo "6) [Backup]   Instalar PBS Local"
    echo "7) [Unlock]   Configurar Boot Unlock (YubiKey)"
    echo "8) [Extras]   Criar Container PVEScriptsLocal"
    echo "------------------------------------------------"
    echo "R) REINICIAR O SISTEMA (Recomendado após Etapa 3)"
    echo "0) Sair"
    echo ""
    read -p "Opção: " OPTION

    case $OPTION in
        1) step_01_system ;;
        2) step_02_gui ;;
        3) step_03_hardware ;;
        4) step_04_storage ;;
        5) step_05_polish ;;
        6) step_06_pbs ;;
        7) step_07_boot_unlock ;;
        8) step_08_pvescripts ;;
        r|R) reboot ;;
        0) exit 0 ;;
        *) echo "Opção inválida." ; sleep 1 ;;
    esac
done
