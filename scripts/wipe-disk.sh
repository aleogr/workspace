#!/bin/sh

cat /proc/partitions
ls /dev/sd*
ls /dev/nvme*
dd if=/dev/zero of=/dev/sda bs=1M count=1