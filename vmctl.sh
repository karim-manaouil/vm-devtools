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

# Check router.sh script for more details
route_br_to_internet(){
        LOCAL="$1"
        INTERNET="$2"

        echo "1" > /proc/sys/net/ipv4/ip_forward

        iptables -t nat -A POSTROUTING -o $INTERNET -j MASQUERADE --random
        iptables -A FORWARD -i $LOCAL -o $INTERNET -j ACCEPT
        iptables -A FORWARD -i $INTERNET -o $LOCAL -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
}

launch_vm(){
	qemu-system-x86_64 \
		-enable-kvm \
		-smp 4 \
		-m 2G \
		-kernel $BZIMAGE \
		-append "root=/dev/sda rw console=ttyS0 earlyprintk apic=verbose" \
		-hda "$1.img" \
		-nographic \
		-netdev tap,id=mynet1,ifname="$2",script=no,downscript=no \
		-device e1000,netdev=mynet1,mac="54:54:00:00:$(($RANDOM%100)):$(($RANDOM%100))"
}

check_iface_exist(){
        for iface in "${@}"; do
                check=$(ip link sh $iface 2>&1)
                if [ "$?" -eq "0" ]; then
                        return 1
                fi
        done
        return 0
}

check_is_bridge(){
        ip link show type bridge | grep -q $1
        return $?
}

# ./vmctl network br tap1 tap2 ...
# ./vmctl route br internet
# ./vmctl vm name tap
main(){
        # Because of tap
	if [ "$(id -u)" -ne 0 ]; then
		echo "You must be root!"
		exit 1
        fi

        if [ "$1" == "vm" ]; then
                launch_vm "$2" "$3"

        elif [ "$1" == "network" ]; then
                check_iface_exist "${@:2}"
                if [ $? -eq 1 ]; then
                        echo "Interface already exists!"
                        exit 1
                fi

                create_bridge "$2"
                echo "Created bridge $2"

                # Enslave the taps to the bridge
                for tap in "${@:3}"; do
                        create_tap $tap "$2"
                        echo "Created $tap and enslaved to $2"
                done
                echo "Done"

        elif [ "$1" == "route" ]; then
                check_iface_exist "$2"
                if [ $? -eq 1 ]; then
                        check_iface_exist "$3"
                        if [ $? -eq 1 ]; then
                                check_is_bridge "$2"
                                if [ $? -eq 0 ]; then
                                        route_br_to_internet "$2" "$3"
                                        echo "Traffic from $2 is routed to $3"
                                        exit 0
                                fi
                        fi
                fi
                echo "Interface does not exist or $2 is not a bridge!"
                exit 1

        elif [ "$1" == "allow-ping" ]; then
                allow_vm_ping
        fi
}

main $@
