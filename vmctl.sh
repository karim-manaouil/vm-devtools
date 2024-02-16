#!/bin/bash

kernel="src"
kernel_path="/home/karim/linux/$kernel"
switch=br0
BZIMAGE="$kernel_path/arch/x86/boot/bzImage"

create_bridge(){
	ip link add $1 type bridge
        ip address add 192.168.100.1/24 dev $1
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
# TODO: Debian 11+ switched to nftables,
#	convert this code to work with it.
route_br_to_internet(){
        LOCAL="$1"
        INTERNET="$2"

        echo "1" > /proc/sys/net/ipv4/ip_forward

        iptables -t nat -A POSTROUTING -o $INTERNET -j MASQUERADE --random
        iptables -A FORWARD -i $LOCAL -o $INTERNET -j ACCEPT
        iptables -A FORWARD -i $INTERNET -o $LOCAL -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
}

launch_vm(){
        # addtional disk argument
        hdb=
        if [ -n "$3" ]; then
                hdb="-hdb $3"
        fi

	gdb=""
	if [[ -v GDB ]]; then
		gdb="-s -S"
	fi

	kcmdline=(
		"root=/dev/sda"
		"rw console=ttyS0"
		"earlyprintk"
		#"apic=verbose"
		"systemd.unified_cgroup_hierarchy=1"
		"nokaslr"
		#"memmap=1G\$0x80000000"
		#"memory_hotplug.memmap_on_memory=1"
		#"hugepagesz=2M hugepages=10"
		#hugepagesz=1G hugepages=1"
	)

	# For this memory config
	# on x86-64, Qemu generates
	# last node at 0x240000000.
	# That's the value passed
	# to memmap kernel boot arg
	# above.

	#-numa node,nodeid=2,memdev=cxl \
	#-object memory-backend-ram,size=2G,id=cxl \
	qemu-system-x86_64 \
		-enable-kvm \
		-cpu host \
		-smp 32,sockets=2 \
		-m 32G \
		-object memory-backend-ram,size=16G,policy=bind,host-nodes=2,id=m0 \
		-object memory-backend-ram,size=16G,policy=bind,host-nodes=3,id=m1 \
		-numa node,nodeid=0,memdev=m0 \
		-numa node,nodeid=1,memdev=m1 \
		-numa cpu,node-id=0,socket-id=0 \
		-numa cpu,node-id=1,socket-id=1 \
		-numa dist,src=0,dst=1,val=11 \
		-kernel $BZIMAGE \
		-append "${kcmdline[*]}" \
		-drive format=raw,file="$1.img" \
		-virtfs local,path=$kernel_path,security_model=none,mount_tag=kernel \
		-netdev tap,id=mynet1,ifname="$2",script=no,downscript=no \
		-device e1000,netdev=mynet1,mac="54:54:00:00:13:14" \
		-monitor telnet:localhost:17555,server,nowait \
		-display none \
		-serial pty \
		-daemonize \
		$gdb
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

do_cpupin(){
	nr_nodes=$1
	tids=()
	i=0

	# Read thread ids of qemu vCPUs via qemu telnet console.
	output=$(echo "info cpus" |\
		nc -q 1 localhost 17555 |\
		tr -d '\r' | cut -d= -f2 |\
		grep -a "^[0-9]")

	while IFS= read -r line; do
		tids+=("$line")
	done <<< "$output"

	div=$((${#tids[@]} / $nr_nodes))

	for ((i = 0; i < ${#tids[@]}; i++)); do
		if [ "$(($i % $div))" -eq 0 ]; then
			shift
			cpu_i=0
			cpu_list=()
			output=$(numactl -H |\
				grep "node $1 cpus" |\
				cut -d":" -f2)
			for cpu in ${output[@]}; do
				cpu_list+=("$cpu")
			done
		fi
		taskset -p -c "${cpu_list[$cpu_i]}" "${tids[i]}"
		cpu_i=$(($cpu_i + 1))
	done
}

# ./vmctl network br tap1 tap2 ...
# ./vmctl route br internet
# [GDB=1] ./vmctl vm name tap --disk
main(){
        # Because of tap
	if [ "$(id -u)" -ne 0 ]; then
		echo "You must be root!"
		exit 1
        fi

        if [ "$1" == "start" ]; then
                add_disk=
                if [ "$4" == "--disk" ]; then
                        add_disk="$5"
                fi
                launch_vm "$2" "$3" "$add_disk"

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
        elif [ "$1" == "default" ]; then
                ./vmctl.sh start "images/vm" tap1
        elif [ "$1" == "cpupin" ]; then
		shift
		do_cpupin $@
	else
		echo "Nothing to do!"
	fi
}

main $@
