#!/bin/bash

exec >> /var/log/libvirt-hook.log 2>&1

cpupower frequency-set -g powersave

USER_NAME="aleogr"
USER_ID=$(id -u "$USER_NAME")

export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus"

sudo -u "$USER_NAME" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  gsettings set org.gnome.desktop.session idle-delay 900

sudo -u "$USER_NAME" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 1800

sudo -u "$USER_NAME" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800

sudo -u "$USER_NAME" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'suspend'

sudo -u "$USER_NAME" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend'

exit 0
