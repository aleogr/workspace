#!/bin/bash

exec >> /var/log/libvirt-hook.log 2>&1

ALL_CPUS="0-31"

echo "[Hook] Restaurando acesso total às CPUs para o host: $ALL_CPUS"

systemctl set-property --runtime -- user.slice AllowedCPUs=$ALL_CPUS
systemctl set-property --runtime -- system.slice AllowedCPUs=$ALL_CPUS
systemctl set-property --runtime -- init.scope AllowedCPUs=$ALL_CPUS

exit 0
