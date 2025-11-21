#!/bin/bash
# 07-setup-boot-unlock-v2.sh
# Objetivo: Configurar prompt de desbloqueio ZFS interativo no Boot.

SERVICE_FILE="/etc/systemd/system/zfs-load-key.service"

if [ "$EUID" -ne 0 ]; then echo "Por favor, rode como root"; exit 1; fi

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
    echo -e "${YW}Security: ZFS Boot Unlock Service${CL}"
    echo ""
}

header_info

echo -e "${GN}>>> [1/2] Criando serviço de desbloqueio ZFS...${CL}"

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

echo "[OK] Serviço criado em: $SERVICE_FILE"

echo -e "${GN}>>> [2/2] Ativando o serviço no boot...${CL}"
systemctl daemon-reload
systemctl enable zfs-load-key

echo -e "${GN}✅ Configuração Concluída!${CL}"
echo "----------------------------------------------------------------"
echo -e "${YW}NO PRÓXIMO REBOOT:${CL}"
echo "1. O sistema vai pausar nas letras brancas de inicialização."
echo "2. Vai aparecer: 'Enter passphrase for tank:'"
echo "3. Digite seu PIN + Segure a YubiKey."
echo "4. O boot continuará e as VMs iniciarão automaticamente."
echo "----------------------------------------------------------------"
