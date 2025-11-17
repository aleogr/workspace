#!/bin/bash

exec >> /var/log/libvirt-hook.log 2>&1

GPU_ID="10de:2203"
AUDIO_ID="10de:1aef"

GPU_ID_SYS="0000:$(lspci -n -d $GPU_ID | cut -d' ' -f1)"
AUDIO_ID_SYS="0000:$(lspci -n -d $AUDIO_ID | cut -d' ' -f1)"

echo "[Hook] Desvinculando de todos os drivers..."
echo "$GPU_ID_SYS" > /sys/bus/pci/drivers/vfio-pci/unbind || true
echo "$AUDIO_ID_SYS" > /sys/bus/pci/drivers/vfio-pci/unbind || true
echo "$GPU_ID_SYS" > /sys/bus/pci/drivers/nouveau/unbind || true
echo "$AUDIO_ID_SYS" > /sys/bus/pci/drivers/nouveau/unbind || true

echo "[Hook] Carregando driver nvidia do host..."
modprobe nvidia_uvm
modprobe nvidia_drm
modprobe nvidia_modeset
modprobe nvidia

echo "[Hook] Vinculando GPU ao driver nvidia para reset..."
echo "$GPU_ID_SYS" > /sys/bus/pci/drivers/nvidia/bind

sleep 5

echo "[Hook] Desvinculando GPU do driver nvidia..."
echo "$GPU_ID_SYS" > /sys/bus/pci/drivers/nvidia/unbind

echo "[Hook] Descarregando driver nvidia..."
rmmod nvidia_uvm
rmmod nvidia_drm
rmmod nvidia_modeset
rmmod nvidia
rmmod nouveau || true

echo "[Hook] Reset da GPU completo."

exit 0
