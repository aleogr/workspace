#!/bin/bash

apt update && apt upgrade
apt install \
	build-essential \
	nvidia-kernel-dkms
