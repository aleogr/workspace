#!/bin/bash
# =================================================================
# 07-setup-boot-unlock.sh
# Objetivo: Configurar prompt de desbloqueio ZFS interativo no Boot.
# =================================================================

SERVICE_FILE="/etc/systemd/system/zfs-load-key.service"

if [ "$EUID" -ne 0 ]; then echo "Por favor, rode como root"; exit 1; fi

echo ">>> [1/2] Criando serviço de desbloqueio ZFS..."

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

echo "[OK] Arquivo de serviço criado em: $SERVICE_FILE"

echo ">>> [2/2] Ativando o serviço no boot..."
systemctl daemon-reload
systemctl enable zfs-load-key

echo "✅ Configuração Concluída!"
echo "----------------------------------------------------------------"
echo "NO PRÓXIMO REBOOT:"
echo "1. O sistema vai pausar nas letras brancas de inicialização."
echo "2. Vai aparecer: 'Enter passphrase for tank:'"
echo "3. Digite seu PIN + Segure a YubiKey."
echo "4. O boot continuará e as VMs iniciarão automaticamente."
echo "----------------------------------------------------------------"
