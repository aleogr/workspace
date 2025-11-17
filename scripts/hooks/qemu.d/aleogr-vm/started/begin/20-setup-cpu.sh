#!/bin/bash

exec >> /var/log/libvirt-hook.log 2>&1

HOST_CPUS_WHEN_VM_ONLINE="14,15,24-31"
echo "[Hook] Limitando host às CPUs: $HOST_CPUS_WHEN_VM_ONLINE"

systemctl set-property --runtime -- user.slice AllowedCPUs=$HOST_CPUS_WHEN_VM_ONLINE
systemctl set-property --runtime -- system.slice AllowedCPUs=$HOST_CPUS_WHEN_VM_ONLINE
systemctl set-property --runtime -- init.scope AllowedCPUs=$HOST_CPUS_WHEN_VM_ONLINE

exit 0
