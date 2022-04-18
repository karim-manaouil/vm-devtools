#!/bin/bash

switch=br0
BZIMAGE="/home/karim/knc-kernel/arch/x86/boot/bzImage"

create_bridge(){
	ip link add $1 type bridge
	ip link set $1 up
}

create_tap(){
	if [ -n "$1" ];then
		ip tuntap add $1 mode tap user `whoami`
		ip link set $1 up
		ip link set $1 master $2
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
		-hda "$1.img" \
		-nographic \
		-netdev tap,id=mynet1,ifname="$2",script=no,downscript=no \
		-device e1000,netdev=mynet1,mac="54:54:00:00:$(($RANDOM%100)):$(($RANDOM%100))"
}

# ./vmctl network br tap1 tap2 ...
# ./vmctl vm name tap
main(){
        # Because of tap
	if [ "$(id -u)" -ne 0 ]; then
		echo "You must be root!"
		exit 1
        fi

        if [ "$1" == "network" ]; then
                for iface in "${@:2}"; do
                        check_network=$(ip link sh "$iface" 2>&1)
                        if [ "$?" -eq "0" ]; then
                                echo "Network $iface already exists!"
                                exit 1
                        fi
                done

                create_bridge "$2"
                echo "Created bridge $2"

                # Enslave the taps to the bridge
                for tap in "${@:3}"; do
                        create_tap $tap "$2"
                        echo "Created $tap and enslaved to $2"
                done
                echo "Done"
        elif [ "$1" == "vm" ]; then
                launch_vm "$2" "$3"
        fi
}

main $@
