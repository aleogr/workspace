#!/bin/bash

apt install \
	gnome-shell \
	gnome-session \
	gnome-terminal \
	mutter \
	gdm3
systemctl enable gdm3
