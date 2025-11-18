#!/bin/bash

apt install \
	gnome-shell \
	gnome-session \
	gnome-terminal \
	mutter \
	gdm3

CONFIG_FILE="/etc/gdm3/daemon.conf"

if grep -q "WaylandEnable=" "$CONFIG_FILE"; then
    sed -i.bak 's/^#*WaylandEnable=.*$/WaylandEnable=true/' "$CONFIG_FILE"
else
    sed -i.bak '/^\[daemon\]/a WaylandEnable=true' "$CONFIG_FILE"
fi

systemctl enable gdm3
