#!/bin/bash
# 02-desktop-gui.sh
# Objetivo: Instalar Interface Gráfica, Xorg Drivers e criar usuário.

# --- VARIÁVEIS DE CONFIGURAÇÃO ---
NEW_USER="aleogr"
# ---------------------------------

# Verifica se está rodando como root
if [ "$EUID" -ne 0 ]; then echo "Por favor, rode como root"; exit 1; fi

echo "=== CONFIGURAÇÃO DE USUÁRIO ==="
echo "O usuário será: $NEW_USER"
echo "Digite a senha para este usuário (não aparecerá na tela):"
read -s PASSWORD
echo "Confirme a senha:"
read -s PASSWORD_CONFIRM

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo "Erro: As senhas não coincidem."
    exit 1
fi

echo ">>> [1/3] Instalando XFCE, LightDM, Chromium e Drivers de Vídeo..."
apt install -y xfce4 xfce4-goodies lightdm chromium sudo xorg xserver-xorg-video-all xserver-xorg-input-all --no-install-recommends

echo ">>> [2/3] Configurando usuário $NEW_USER..."
if id "$NEW_USER" &>/dev/null; then
    echo "Usuário já existe. Atualizando senha..."
    echo "$NEW_USER:$PASSWORD" | chpasswd
else
    useradd -m -s /bin/bash "$NEW_USER"
    echo "$NEW_USER:$PASSWORD" | chpasswd
    usermod -aG sudo "$NEW_USER"
    echo "[OK] Usuário criado."
fi

echo ">>> [3/3] Configurando Autostart do Proxmox..."
AUTOSTART_DIR="/home/$NEW_USER/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat <<EOF > "$AUTOSTART_DIR/proxmox-ui.desktop"
[Desktop Entry]
Type=Application
Name=Proxmox UI
Exec=chromium --no-sandbox --ignore-certificate-errors --app=https://localhost:8006
StartupNotify=false
Terminal=false
EOF

# Corrige permissões
chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.config"

# Ativa o display manager
systemctl enable lightdm
systemctl start lightdm

echo "✅ Desktop Configurado!"
