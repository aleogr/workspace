#!/bin/bash

# Script simplificado para preparar o host Debian 13 para
# os hooks de reset da GPU NVIDIA.
#
# ASSUME QUE:
# 1. Você está executando como root (sudo).
# 2. Você irá baixar e instalar seus próprios scripts
#    (/etc/libvirt/hooks/qemu e .../release/end) manualmente.

# Para o script se algum comando falhar
set -e

echo "--- 1. Habilitando repositórios 'contrib' e 'non-free' ---"
# Usa 'sed' para encontrar e substituir as linhas de 'main',
# adicionando 'contrib non-free'
sed -i.bak \
  -e 's/ main non-free-firmware/ main contrib non-free non-free-firmware/g' \
  -e 's/ main$/ main contrib non-free non-free-firmware/' \
  /etc/apt/sources.list

echo "Arquivo /etc/apt/sources.list atualizado (backup salvo em .bak)."

# --- 2. Instalando o módulo de kernel da NVIDIA ---
echo "--- 2. Atualizando Apt e instalando 'nvidia-kernel-dkms' ---"
apt update
apt install -y nvidia-kernel-dkms

# --- 3. Habilitando o sistema de Hooks no Libvirt ---
echo "--- 3. Habilitando hooks no /etc/libvirt/qemu.conf ---"
# Verifica se a linha está habilitada, comentada, ou ausente
if ! grep -q '^qemu_hook_script = "/etc/libvirt/hooks/qemu"' /etc/libvirt/qemu.conf; then
    if grep -q '^#qemu_hook_script = "/etc/libvirt/hooks/qemu"' /etc/libvirt/qemu.conf; then
        # Se estiver comentada, descomenta
        sed -i.bak 's/^#qemu_hook_script = "\/etc\/libvirt\/hooks\/qemu"/qemu_hook_script = "\/etc\/libvirt\/hooks\/qemu"/' /etc/libvirt/qemu.conf
        echo "Hook descomentado."
    else
        # Se não existir, adiciona
        echo 'qemu_hook_script = "/etc/libvirt/hooks/qemu"' >> /etc/libvirt/qemu.conf
        echo "Hook adicionado."
    fi
else
    echo "Hook já estava habilitado."
fi

# --- 4. Criando Blacklist do Driver no Boot ---
echo "--- 4. Criando blacklist para o driver nvidia no boot ---"
cat << EOF > /etc/modprobe.d/99-blacklist-nvidia-vfio.conf
# Impede o driver nvidia de carregar no boot (será usado apenas pelo hook)
blacklist nvidia
blacklist nouveau
EOF

# --- 5. Atualizando o Sistema ---
echo "--- 5. Atualizando initramfs (pode demorar um pouco)... ---"
update-initramfs -u

echo "--- 6. Reiniciando serviço libvirtd ---"
systemctl restart libvirtd.service

echo "------------------------------------------------------"
echo "✅ SUCESSO! O host está pronto."
echo ""
echo "Suas próximas etapas:"
echo " 1. Baixe seu script 'qemu' (roteador) para /etc/libvirt/hooks/"
echo " 2. Baixe seu script 'end' (reset) para /etc/libvirt/hooks/qemu.d/SuaVM/release/"
echo " 3. Certifique-se de que ambos sejam executáveis (chmod +x)."
echo " 4. REINICIE O HOST ('sudo reboot') antes de testar."
echo "------------------------------------------------------"
