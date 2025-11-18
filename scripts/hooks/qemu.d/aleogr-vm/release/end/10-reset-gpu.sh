#!/bin/bash

exec >> /var/log/libvirt-hook.log 2>&1
echo "/etc/libvirt/hooks/qemu.d/aleogr-games/release/end/10-reset-gpu.sh"

GPU_ID="10de:2203"
AUDIO_ID="10de:1aef"
GPU_ID_SYS="0000:$(lspci -n -d $GPU_ID | cut -d' ' -f1)"
AUDIO_ID_SYS="0000:$(lspci -n -d $AUDIO_ID | cut -d' ' -f1)"

echo "[Hook] Desvinculando do vfio-pci (se ainda estiver vinculado)..."
echo "$GPU_ID_SYS" > /sys/bus/pci/drivers/vfio-pci/unbind || true
echo "$AUDIO_ID_SYS" > /sys/bus/pci/drivers/vfio-pci/unbind || true

echo "[Hook] Desvinculando do nouveau (por segurança)..."
echo "$GPU_ID_SYS" > /sys/bus/pci/drivers/nouveau/unbind || true
echo "$AUDIO_ID_SYS" > /sys/bus/pci/drivers/nouveau/unbind || true

echo "[Hook] Carregando driver nvidia do host (o auto-bind fará o reset)..."
modprobe nvidia_uvm
modprobe nvidia_drm
modprobe nvidia_modeset
modprobe nvidia

sleep 5

echo "[Hook] Reset da GPU completo. Deixando drivers do host carregados."

exit 0
