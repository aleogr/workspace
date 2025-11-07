#!/bin/bash

pacman -Syu

pacman -S --needed \
  xorg-server

pacman -S --needed \
  xfce4-whiskermenu-plugin \
  xfce4-pulseaudio-plugin \
  xfce4-clipman-plugin \
  xfce4-screensaver \
  xfce4-settings \
  xfce4-session \
  xfce4-panel \
  libxfce4util \
  alacritty \
  garcon \
  xfconf \
  xfwm4 \
  exo \

pacman -S --needed \
  lightdm-gtk-greeter \
  lightdm

pacman -S --needed \
  network-manager-applet \
  networkmanager \
  ttf-liberation \
  ttf-dejavu

pacman -S --needed \
  tmux \
  zsh

curl -O https://blackarch.org/strap.sh
chmod +x strap.sh
sudo ./strap.sh
pacman -S --needed \
  blackarch-config-xfce
pacman -Sg | grep blackarch
echo "pacman -S blackarch-<category>"

systemctl enable lightdm.service
systemctl enable NetworkManager.service
