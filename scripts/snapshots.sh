#!/bin/bash

apt install --no-install-recommends \
	timeshift \
	inotify-tools

timeshift --create --comments "First snapshot"

cd /tmp && wget \
	https://github.com/Antynea/grub-btrfs/archive/refs/heads/master.zip \
	-O grub-btrfs.zip

unzip -o grub-btrfs.zip && cd grub-btrfs-master
make install
grub-mkconfig

SERVICE_NAME="grub-btrfsd.service"
SERVICE_OVERRIDE_PATH="/etc/systemd/system/${SERVICE_NAME}"
LINE_OLD='ExecStart=/usr/bin/grub-btrfsd --syslog /.snapshots'
LINE_NEW='ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto'

SERVICE_SOURCE_PATH=$(find /usr/lib/systemd/system /lib/systemd/system -name "${SERVICE_NAME}" 2>/dev/null | head -n 1)

if [ -z "$SERVICE_SOURCE_PATH" ]; then
    exit 1
fi

if [ ! -f "$SERVICE_OVERRIDE_PATH" ]; then
    sudo cp "$SERVICE_SOURCE_PATH" "$SERVICE_OVERRIDE_PATH"
fi

sudo sed -i "s|${LINE_OLD}|${LINE_NEW}|g" "$SERVICE_OVERRIDE_PATH"

if sudo grep -q "$LINE_NEW" "$SERVICE_OVERRIDE_PATH"; then
    sudo systemctl daemon-reload
    sudo systemctl enable --now ${SERVICE_NAME}
    exit 0
else
    exit 1
fi