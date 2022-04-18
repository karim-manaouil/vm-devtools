#!/bin/bash

switch=br0
BZIMAGE="/home/karim/knc-kernel/arch/x86/boot/bzImage"

create_bridge(){
	ip link add $switch type bridge
	ip link set $switch up
}

create_tap(){
	if [ -n "$1" ];then
		ip tuntap add $1 mode tap user `whoami`
		ip link set $1 up
		ip link set $1 master $switch
	else
		echo "Error: no interface specified"
		exit 1
	fi
}

allow_vm_ping(){
	dir="/proc/sys/net/bridge"
	for f in $dir/bridge-nf-*; do 
		echo 0 > $f; 
	done
}

launch_vm(){
	qemu-system-x86_64 \
		-enable-kvm \
		-smp 4 \
		-m 2G \
		-kernel $BZIMAGE \
		-append "root=/dev/sda rw console=ttyS0" \
		-hda disk$1.img \
		-nographic \
		-netdev tap,id=mynet$1,ifname=tap$1,script=no,downscript=no \
		-device e1000,netdev=mynet$1,mac=52:54:00:12:34:5$1
}

main(){
	check_network=$(ip link sh $switch 2>&1)
	ret=$?

	if [ "$(id -u)" -ne 0 ]; then
		echo "You must be root!"
		exit 1
	fi

	if [ "$ret" -eq 1 ]; then
		create_bridge
		create_tap tap1
		create_tap tap2
		allow_vm_ping
	fi

	launch_vm $1
}

main $@
