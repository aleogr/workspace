#!/bin/bash

apt install xfce4 chromium lightdm -y
adduser aleogr
systemctl start lightdm
