#!/bin/bash
# ==============================================================================
# MASTER SETUP SCRIPT - ALEOGR-PC (Release v1.0.0)
# ==============================================================================
# Complete automation for Proxmox Workstation with Passthrough, ZFS, and Hardening.
# Versioning: SemVer 1.0.0 (Stable - Audio Fix & U2F Array Logic)
# ==============================================================================

# --- GLOBAL VARIABLES (EDIT HERE) ---
# ------------------------------------------------------------------------------
SCRIPT_VERSION="1.0.0"
NEW_USER="aleogr"
DEBIAN_CODENAME="trixie"

# Automatic disk selection based on environment (Real vs VM)
if systemd-detect-virt | grep -q "none"; then
    # Real Hardware (WD SN850X)
    DISK_DEVICE="/dev/disk/by-id/nvme-WD_BLACK_SN850X_2000GB_222503A00551"
else
    # Virtual Environment (Testing)
    DISK_DEVICE="/dev/sdb"
fi

POOL_NAME="tank"
STORAGE_ID_VM="VM-Storage"
DATASTORE_PBS="Backup-PBS"
ZFS_ARC_GB=8
CPU_GOVERNOR="powersave" # 'powersave' = Balanced (Recommended for modern Intel)
ENABLE_ENCRYPTION="yes"  # "yes" or "no"
# ------------------------------------------------------------------------------

# Colors
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")

# Header Function (HereDoc for ASCII security)
header() {
    clear
    echo -e "${BL}"
    cat << "EOF"
   __   __   ____  __   ___  ____
  / _\ (  ) (  __)/  \ / __)(  _ \
 /    \/ (_/\) _)(  O ( (_ \ )   /
 \_/\_/\____/(____)\__/ \___/(__\_)
EOF
    echo -e "${CL}"
    echo -e "${YW}Workstation: aleogr-pc${CL}"
    echo -e "${YW}Version: ${GN}v${SCRIPT_VERSION}${CL}"
    echo ""
    echo -e "${YW}VALIDATED HARDWARE (Target):${CL}"
    echo -e " • MB:  ${GN}ASUS ROG MAXIMUS Z790 HERO${CL}"
    echo -e " • CPU: ${GN}Intel Core i9-13900K${CL}"
    echo -e " • GPU: ${GN}NVIDIA GeForce RTX 3090 Ti${CL}"
    echo -e " • RAM: ${GN}64GB DDR5${CL}"
    echo -e " • SSD: ${GN}WD Black SN850X (Data)${CL} + NVMe (OS)"
    echo ""
    
    if ! systemd-detect-virt | grep -q "none"; then
        echo -e "${RD}[!] VIRTUAL ENVIRONMENT DETECTED ($(systemd-detect-virt))${CL}"
        echo -e "${RD}[!] Step 03 (Hardware Tune) will be locked.${CL}"
        echo ""
    fi
}

if [ "$EUID" -ne 0 ]; then echo "Please run as root"; exit 1; fi

# ==============================================================================
# EXECUTION MODULES
# ==============================================================================

step_01_system() {
    echo -e "${GN}>>> STEP 01: Base System & Repositories${CL}"
    
    mkdir -p /etc/apt/sources.list.d/backup_old
    mv /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/backup_old/ 2>/dev/null || true
    mv /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/backup_old/ 2>/dev/null || true
    
    if [ -f /etc/apt/sources.list ]; then echo "# Moved to debian.sources" > /etc/apt/sources.list; fi

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

    echo "Updating system..."
    apt update && apt dist-upgrade -y
    
    echo "Installing tools..."
    apt install -y intel-microcode build-essential pve-headers vim htop btop curl git fastfetch ethtool net-tools nvtop

    if [ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]; then
        sed -Ezi.bak 's/(Ext.Msg.show\(\{\s+title: gettext\('"'"'No valid subscription'"'"'\),)/void\(\{ \/\/\1/g' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
        systemctl restart pveproxy.service
        echo -e "${BL}[INFO] Subscription Notice Removed.${CL}"
    fi

    apt autoremove -y && apt clean
    echo -e "${GN}✅ Step 01 Completed.${CL}"
    read -p "Press Enter to return to the menu..."
}

step_02_gui() {
    echo -e "${GN}>>> STEP 02: Desktop GUI, Audio & Kiosk${CL}"
    echo "Set password for Linux user ($NEW_USER):"
    read -s PASSWORD
    echo "Confirm:"
    read -s PASSWORD_CONFIRM
    
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then 
        echo -e "${RD}Passwords do not match!${CL}"
        read -p "Enter..."
        return
    fi

    echo "Installing XFCE, Video Drivers, and Audio System (Pipewire/RTKit)..."
    # Added rtkit and dbus-user-session for proper Audio init on boot
    apt install -y xfce4 xfce4-goodies lightdm chromium sudo xorg xserver-xorg-video-all xserver-xorg-input-all pipewire pipewire-pulse wireplumber pavucontrol alsa-utils rtkit dbus-user-session --no-install-recommends

    if id "$NEW_USER" &>/dev/null; then
        printf "%s:%s\n" "$NEW_USER" "$PASSWORD" | chpasswd
    else
        useradd -m -s /bin/bash "$NEW_USER"
        printf "%s:%s\n" "$NEW_USER" "$PASSWORD" | chpasswd
        # Added to audio/video/render groups
        usermod -aG sudo,audio,video,render "$NEW_USER"
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
    
    # Unmute master just in case
    amixer sset Master unmute > /dev/null 2>&1 || true
    amixer sset Master 100% > /dev/null 2>&1 || true

    systemctl enable lightdm
    
    echo -e "${GN}✅ Step 02 Completed.${CL}"
    echo -e "${YW}Note: Audio and GUI will start after Reboot.${CL}"
    read -p "Press Enter to return to the menu..."
}

step_03_hardware() {
    if ! systemd-detect-virt | grep -q "none"; then
        echo -e "${RD}ERROR: Locked in VM.${CL}"; read -p "Enter..."; return
    fi

    echo -e "${GN}>>> STEP 03: Hardware Tune (i9 + GPU)${CL}"
    ZFS_BYTES=$(($ZFS_ARC_GB * 1024 * 1024 * 1024))
    cp /etc/kernel/cmdline /etc/kernel/cmdline.bak
    
    CMDLINE="intel_iommu=on iommu=pt pci=noaer nvme_core.default_ps_max_latency_us=0 split_lock_detect=off video=efifb:off video=vesafb:off video=simplefb:off initcall_blacklist=sysfb_init"
    echo "root=ZFS=rpool/ROOT/pve-1 boot=zfs $CMDLINE" > /etc/kernel/cmdline
    proxmox-boot-tool refresh

    echo "Configuring CPU Governor ($CPU_GOVERNOR)..."
    apt install -y linux-cpupower
    
    cat <<EOF > /etc/systemd/system/cpupower-governor.service
[Unit]
Description=Set CPU Governor to $CPU_GOVERNOR
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g $CPU_GOVERNOR

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable --now cpupower-governor.service
    cpupower frequency-set -g $CPU_GOVERNOR

    echo "options kvm ignore_msrs=1 report_ignored_msrs=0" > /etc/modprobe.d/kvm.conf
    echo "options zfs zfs_arc_max=$ZFS_BYTES" > /etc/modprobe.d/zfs.conf

    update-pciids > /dev/null 2>&1 || true
    GPU_IDS=$(lspci -nn | grep -i nvidia | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}(?=\])' | tr '\n' ',' | sed 's/,$//')

    if [ -n "$GPU_IDS" ]; then
        echo "GPU Detected: $GPU_IDS"
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
        echo "${YW}[WARNING] Nvidia GPU not found.${CL}"
    fi

    update-initramfs -u -k all
    echo -e "${GN}✅ Step 03 Completed. REBOOT REQUIRED!${CL}"
    read -p "Press Enter to return to the menu..."
}

step_04_storage() {
    echo -e "${GN}>>> STEP 04: Storage ZFS ($DISK_DEVICE)${CL}"
    
    if systemd-detect-virt | grep -q "none"; then
        if ! cat /proc/cmdline | grep -q "nvme_core.default_ps_max_latency_us=0"; then
            echo -e "${RD}CRITICAL SECURITY ERROR!${CL}"
            echo -e "NVMe protection parameter (Step 3) is NOT active in current Kernel."
            echo -e "If you format now, the WD SN850X disk may freeze the system."
            echo -e "${YW}SOLUTION: Reboot PC and run Step 04 afterwards.${CL}"
            read -p "Press Enter to abort..."
            return
        fi
    fi

    if zpool list -o name -H | grep -q "^$POOL_NAME$"; then
        echo -e "${RD}ERROR: Pool '$POOL_NAME' already exists! Aborting.${CL}"; read -p "Enter..."; return
    fi

    if [ ! -b "$DISK_DEVICE" ]; then echo "${RD}Error: Disk $DISK_DEVICE not found!${CL}"; read -p "Enter..."; return; fi
    
    echo -e "${RD}!!! WARNING: THIS WILL FORMAT DISK: $DISK_DEVICE !!!${CL}"
    echo -e "All data on this device will be lost."
    echo "Type 'CONFIRM' to continue:"
    read -r INPUT
    if [ "$INPUT" != "CONFIRM" ]; then return; fi

    sgdisk --zap-all "$DISK_DEVICE" > /dev/null
    wipefs -a "$DISK_DEVICE" > /dev/null

    ZPOOL_ARGS="-f -o ashift=12 -o autotrim=on -O compression=lz4 -O atime=off -O acltype=posixacl -O xattr=sa"
    if [ "$ENABLE_ENCRYPTION" == "yes" ]; then
        echo -e "${YW}Set ZFS PASSWORD (PIN + YubiKey):${CL}"
        ZPOOL_ARGS="$ZPOOL_ARGS -O encryption=aes-256-gcm -O keyformat=passphrase -O keylocation=prompt"
    fi

    if zpool create $ZPOOL_ARGS "$POOL_NAME" "$DISK_DEVICE"; then
        echo "[OK] Pool created."
    else
        echo "${RD}Failed to create Pool.${CL}"; read -p "Enter..."; return
    fi

    zfs create "$POOL_NAME/vms"
    zfs create "$POOL_NAME/backups"
    
    if ! pvesm status | grep -q "$STORAGE_ID_VM"; then
        pvesm add zfspool "$STORAGE_ID_VM" --pool "$POOL_NAME/vms" --content images,rootdir --sparse 1
    fi

    echo "Updating boot cache..."
    update-initramfs -u
    echo -e "${GN}✅ Step 04 Completed.${CL}"
    read -p "Press Enter to return to the menu..."
}

step_05_memory() {
    echo -e "${GN}>>> STEP 05: Memory Tuning & ZFS Swap Creation${CL}"
    
    CONFIG_FILE="/etc/sysctl.d/99-pve-swappiness.conf"
    echo "# Custom configuration for Proxmox ZFS" > "$CONFIG_FILE"
    echo "vm.swappiness=10" >> "$CONFIG_FILE"
    sysctl --system > /dev/null
    echo "Swappiness set to 10."

    if [ $(swapon --show --noheadings | wc -l) -eq 0 ]; then
        echo "No active Swap. Checking ZFS volume..."
        
        if ! zfs list rpool/swap >/dev/null 2>&1; then
            echo "Creating rpool/swap volume (8GB)..."
            zfs create -V 8G -b $(getconf PAGESIZE) \
                -o compression=zle \
                -o logbias=throughput \
                -o sync=always \
                -o primarycache=metadata \
                -o secondarycache=none \
                -o com.sun:auto-snapshot=false \
                rpool/swap
            udevadm settle
            sleep 1
        else
            echo "Warning: Volume 'rpool/swap' already exists. Skipping creation."
        fi
        
        echo "Activating Swap..."
        mkswap -f /dev/zvol/rpool/swap
        swapon /dev/zvol/rpool/swap
        
        if ! grep -q "/dev/zvol/rpool/swap" /etc/fstab; then
            echo "/dev/zvol/rpool/swap none swap defaults 0 0" >> /etc/fstab
        fi
        
        echo -e "${GN}8GB ZFS Swap activated!${CL}"
    else
        CURRENT_SWAP=$(free -h | grep Swap | awk '{print $2}')
        echo -e "${YW}Swap is already active ($CURRENT_SWAP).${CL}"
    fi

    echo -e "${GN}✅ Step 05 Completed.${CL}"
    sleep 1
}

step_06_pbs() {
    echo -e "${GN}>>> STEP 06: Local PBS Installation${CL}"
    apt install -y proxmox-backup-server proxmox-backup-client
    
    ZFS_PATH="/$POOL_NAME/backups"
    if [ -d "$ZFS_PATH" ]; then
        chown -R backup:backup $ZFS_PATH
        chmod 700 $ZFS_PATH
    else
        echo "${RD}Warning: Directory $ZFS_PATH not found.${CL}"; read -p "Enter..."; return
    fi

    if ! proxmox-backup-manager datastore list | grep -q "$DATASTORE_PBS"; then
        proxmox-backup-manager datastore create $DATASTORE_PBS $ZFS_PATH
    fi

    FINGERPRINT=$(proxmox-backup-manager cert info | grep "Fingerprint" | awk '{print $NF}')
    
    echo "Enter Linux ROOT password to connect PVE to PBS:"
    read -s PBS_PASSWORD

    if ! pvesm status | grep -q "$DATASTORE_PBS"; then
        pvesm add pbs "$DATASTORE_PBS" \
            --server 127.0.0.1 \
            --datastore "$DATASTORE_PBS" \
            --fingerprint "$FINGERPRINT" \
            --username "root@pam" \
            --password "$PBS_PASSWORD" \
            --content backup
    fi
    echo -e "${GN}✅ Step 06 Completed.${CL}"
    read -p "Press Enter to return to the menu..."
}

step_07_boot_unlock() {
    echo -e "${GN}>>> STEP 07: Boot Unlock Service${CL}"
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
    echo -e "${GN}✅ Step 07 Completed.${CL}"
    read -p "Press Enter to return to the menu..."
}

step_08_pvescripts() {
    echo -e "${GN}>>> STEP 08: PVEScriptsLocal (Script Manager)${CL}"
    echo -e "This will download and execute the official installer for PVEScriptsLocal LXC."
    echo -e "Source: https://github.com/community-scripts/ProxmoxVE"
    echo ""
    
    if [ ! -f /etc/timezone ]; then
        echo "Creating /etc/timezone file for compatibility..."
        timedatectl show --property=Timezone --value > /etc/timezone
    fi

    echo "Do you want to proceed? (y/n)"
    read -r CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pve-scripts-local.sh)"
        echo -e "${GN}✅ Installation finished.${CL}"
        
        echo "Configuring Kiosk to open new dashboard..."
        CTID=$(pct list | grep "pve-scripts-local" | awk '{print $1}')
        
        if [ -n "$CTID" ]; then
            CTIP=$(pct exec "$CTID" -- ip -4 -br addr show eth0 | awk '{print $3}' | cut -d/ -f1)
            if [ -n "$CTIP" ]; then
                NEW_URL="http://$CTIP:3000"
                DESKTOP_FILE="/home/$NEW_USER/.config/autostart/proxmox-ui.desktop"
                if [ -f "$DESKTOP_FILE" ]; then
                    if ! grep -q "$NEW_URL" "$DESKTOP_FILE"; then
                        sed -i "s|https://localhost:8007|https://localhost:8007 $NEW_URL|" "$DESKTOP_FILE"
                        echo -e "${GN}✅ URL $NEW_URL added to Kiosk!${CL}"
                    else
                        echo "URL already exists in Kiosk."
                    fi
                else
                    echo "${RD}Kiosk file not found. Run Step 02.${CL}"
                fi
            fi
        fi
    else
        echo "Cancelled."
    fi
    read -p "Press Enter to return to the menu..."
}

step_09_multiarch() {
    echo -e "${GN}>>> STEP 09: Multi-Arch Support (LXC Only)${CL}"
    echo -e "${YW}Warning: Installing full emulators (VMs) may cause conflicts.${CL}"
    echo -e "Installing only safe support for Containers (binfmt + qemu-static)."
    
    apt install -y qemu-user-static binfmt-support

    echo -e "${GN}✅ Multi-Arch support for Containers installed!${CL}"
    echo -e "${YW}What you CAN do:${CL}"
    echo " - Run ARM64 or RISC-V LXC Containers."
    echo -e "${RD}What you CANNOT do:${CL}"
    echo " - Create full VMs of other architectures via Proxmox (to protect the host)."
    read -p "Press Enter to return to the menu..."
}

step_10_hardening() {
    echo -e "${GN}>>> STEP 10: Security Hardening (PAM/U2F/Sudo)${CL}"
    echo -e "${YW}This step configures 2FA (YubiKey) for Login and Sudo.${CL}"
    echo -e "You will need your YubiKeys handy now."
    echo ""
    echo "Start Hardening? (y/n)"
    read -r CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then return; fi

    echo "Installing security packages..."
    apt install -y sudo libpam-u2f libpam-pwquality

    echo "Configuring permissions for user $NEW_USER..."
    if [ ! -f "/etc/sudoers.d/$NEW_USER" ]; then
        echo "$NEW_USER ALL=(ALL) ALL" > "/etc/sudoers.d/$NEW_USER"
        chmod 0440 "/etc/sudoers.d/$NEW_USER"
        echo "[OK] Sudoers configured."
    fi

    echo "Configuring PAM (Idempotent)..."
    if ! grep -q "pam_u2f.so" /etc/pam.d/common-auth; then
        sed -i '1i auth sufficient pam_u2f.so cue nouserok authfile=/etc/Yubico/u2f_mappings' /etc/pam.d/common-auth
        echo "[OK] PAM Auth updated."
    fi

    if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
        sed -i '1i password requisite pam_pwquality.so retry=3 minlen=12 difok=4 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 enforce_for_root' /etc/pam.d/common-password
        echo "[OK] PAM Password Quality updated."
    fi

    echo -e "${GN}>>> YUBIKEY REGISTRATION${CL}"
    mkdir -p /etc/Yubico
    MAPPING_FILE="/etc/Yubico/u2f_mappings"
    KEYS_TEMP_FILE=$(mktemp)

    if grep -q "^$NEW_USER" "$MAPPING_FILE" 2>/dev/null; then
        echo -e "${YW}Warning: Keys already registered for $NEW_USER.${CL}"
        echo "Overwrite/Add new? (y/n)"
        read -r OVR
        if [[ ! "$OVR" =~ ^[Yy]$ ]]; then 
            rm "$KEYS_TEMP_FILE"
            echo "Press Enter to return to the menu..."
            read
            return 
        fi
    fi

    COUNT=1
    while true; do
        echo -e "${BL}--- Registering Key #$COUNT ---${CL}"
        echo "Insert YubiKey and press ENTER."
        read
        echo "Touch the YubiKey button now (when flashing)..."
        
        KEY_DATA=$(pamu2fcfg -n)
        # Sanitization: Remove newlines AND leading colons to avoid :: issues
        KEY_DATA_CLEAN=$(echo -n "$KEY_DATA" | tr -d '\n\r[:space:]' | sed 's/^://')
        
        if [ -n "$KEY_DATA_CLEAN" ]; then
            # Save to temp file (one key per line)
            printf "%s\n" "$KEY_DATA_CLEAN" >> "$KEYS_TEMP_FILE"
            echo -e "${GN}Key captured!${CL}"
        else
            echo -e "${RD}Failed to capture key. Try again.${CL}"
        fi

        echo "Remove YubiKey and press ENTER."
        read
        
        echo "Add another key (Backup)? (y/n)"
        read -r MORE
        if [[ ! "$MORE" =~ ^[Yy]$ ]]; then break; fi
        COUNT=$((COUNT+1))
    done

    if [ -s "$KEYS_TEMP_FILE" ]; then
        touch "$MAPPING_FILE"
        grep -v "^$NEW_USER" "$MAPPING_FILE" > "${MAPPING_FILE}.tmp"
        
        # Join lines with : using paste (Guaranteed no duplicates)
        JOINED_KEYS=$(grep -v '^$' "$KEYS_TEMP_FILE" | paste -sd: -)
        
        echo "${NEW_USER}:${JOINED_KEYS}" >> "${MAPPING_FILE}.tmp"
        mv "${MAPPING_FILE}.tmp" "$MAPPING_FILE"
        
        echo -e "${GN}✅ Keys successfully saved to $MAPPING_FILE${CL}"
    else
        echo "${YW}No keys were registered.${CL}"
    fi
    
    rm "$KEYS_TEMP_FILE"
    read -p "Press Enter to return to the menu..."
}

while true; do
    header
    echo -e "${YW}PHASE 1: SYSTEM & HARDWARE (Reboot required at end)${CL}"
    echo " 1) [System]    Base, Repositories & Microcode"
    echo " 2) [Desktop]   GUI XFCE, Audio & Kiosk Mode"
    if systemd-detect-virt | grep -q "none"; then
        echo " 3) [Hardware]  Kernel, IOMMU, GPU & ZFS RAM"
    else
        echo -e "${RD} 3) [Hardware]  (Locked in VM)${CL}"
    fi
    echo ""
    echo -e "${YW}PHASE 2: DATA & SERVICES (Execute after Reboot)${CL}"
    echo " 4) [Storage]   Format Data Disk, ZFS & Encryption"
    echo " 5) [Memory]    Swap Tuning & Swappiness"
    echo " 6) [Backup]    Install Local PBS"
    echo " 7) [Unlock]    Configure Boot Unlock (YubiKey)"
    echo " 8) [Extras]    Create PVEScriptsLocal Container"
    echo " 9) [Emulation] Multi-Arch Support (LXC Only)"
    echo "10) [Hardening] PAM U2F, Sudo & Strong Passwords"
    echo "------------------------------------------------"
    echo " R) REBOOT SYSTEM"
    echo " 0) Exit"
    echo ""
    read -p "Option: " OPTION

    case $OPTION in
        1) step_01_system ;;
        2) step_02_gui ;;
        3) step_03_hardware ;;
        4) step_04_storage ;;
        5) step_05_memory ;;
        6) step_06_pbs ;;
        7) step_07_boot_unlock ;;
        8) step_08_pvescripts ;;
        9) step_09_multiarch ;;
        10) step_10_hardening ;;
        r|R) reboot ;;
        0) exit 0 ;;
        *) echo "Invalid option." ; sleep 1 ;;
    esac
done
