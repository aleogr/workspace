#!/bin/bash
# 02-desktop-gui-v2.sh
# Objetivo: Instalar Interface Gráfica, Drivers Xorg e configurar Kiosk Mode.

# --- CONFIGURAÇÃO ---
NEW_USER="aleogr"
# --------------------

# Verifica Root
if [ "$EUID" -ne 0 ]; then echo "Por favor, rode como root"; exit 1; fi

# Cores
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
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
    echo -e "${YW}Desktop Environment: XFCE + Kiosk Mode${CL}"
    echo ""
}

header_info

echo -e "${YW}=== CONFIGURAÇÃO DE USUÁRIO ===${CL}"
echo "O usuário do sistema será: ${BL}$NEW_USER${CL}"
echo "Digite a senha para este usuário:"
read -s PASSWORD
echo "Confirme a senha:"
read -s PASSWORD_CONFIRM

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo -e "${RD}Erro: As senhas não coincidem.${CL}"
    exit 1
fi

echo -e "${GN}>>> [1/4] Instalando XFCE, Navegador e Drivers de Vídeo...${CL}"
# INCLUI O FIX: xorg e drivers de vídeo genéricos para evitar erro do LightDM
apt install -y xfce4 xfce4-goodies lightdm chromium sudo xorg xserver-xorg-video-all xserver-xorg-input-all --no-install-recommends

echo -e "${GN}>>> [2/4] Configurando usuário $NEW_USER...${CL}"
if id "$NEW_USER" &>/dev/null; then
    echo "Usuário já existe. Atualizando senha..."
    echo "$NEW_USER:$PASSWORD" | chpasswd
else
    useradd -m -s /bin/bash "$NEW_USER"
    echo "$NEW_USER:$PASSWORD" | chpasswd
    usermod -aG sudo "$NEW_USER"
    echo "[OK] Usuário criado."
fi

echo -e "${GN}>>> [3/4] Configurando Autostart (Kiosk PVE + PBS)...${CL}"
AUTOSTART_DIR="/home/$NEW_USER/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat <<EOF > "$AUTOSTART_DIR/proxmox-ui.desktop"
[Desktop Entry]
Type=Application
Name=Proxmox Kiosk
# Abre duas abas: Porta 8006 (PVE) e Porta 8007 (PBS)
Exec=chromium --kiosk --no-sandbox --ignore-certificate-errors https://localhost:8006 https://localhost:8007
StartupNotify=false
Terminal=false
EOF

# Corrige permissões
chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.config"

echo -e "${GN}>>> [4/4] Ativando Interface Gráfica...${CL}"
systemctl enable lightdm
# Não iniciamos o lightdm agora para não interromper o script se rodar no console físico,
# ou iniciamos se quiser ver o resultado já. Vamos iniciar.
systemctl start lightdm

echo -e "${GN}✅ Desktop Configurado!${CL}"
echo -e "${YW}Dica: Use 'Ctrl + Tab' para alternar entre Proxmox VE e Backup Server.${CL}"
