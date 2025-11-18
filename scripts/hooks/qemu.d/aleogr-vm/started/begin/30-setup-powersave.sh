#!/bin/bash

exec >> /var/log/libvirt-hook.log 2>&1

cpupower frequency-set -g performance

USER_NAME="aleogr"
USER_ID=$(id -u "$USER_NAME")

export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus"

sudo -u "$USER_NAME" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  gsettings set org.gnome.desktop.session idle-delay 0

sudo -u "$USER_NAME" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0

sudo -u "$USER_NAME" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0

exit 0
