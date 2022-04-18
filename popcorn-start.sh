#!/bin/bash

BZIMAGE="/home/karim/linux/popcorn-kernel/arch/x86/boot/bzImage"
DISK="popcorn-x86.img"

qemu-system-x86_64 \
    -enable-kvm -cpu host -smp 4 -m 8096 -nographic \
    -kernel $BZIMAGE \
    -append "root=/dev/sda rw console=ttyS0" \
    -drive id=root,media=disk,file=$DISK \
    -netdev type=tap,id=net0,ifname=tap1,script=no,downscript=no \
    -device e1000,netdev=net0,mac=52:55:00:d1:55:4a
