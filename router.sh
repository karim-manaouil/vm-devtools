#!/bin/bash

# From https://serverfault.com/a/1013036/471319

  # Defining interfaces for gateway.
  INTERNET="wlp0s20f3"
  LOCAL="br0"


   # brctl addbr $LOCAL
   # brctl addif $LOCAL $LOCALETH

   # ip addr add 192.168.100.1/24 dev $LOCAL
   # ip link set $LOCAL up

   # IMPORTANT: Activate IP-forwarding in the kernel!

   # Disabled by default!
   echo "1" > /proc/sys/net/ipv4/ip_forward

   # Load various modules. Usually they are already loaded 
   # (especially for newer kernels), in that case 
   # the following commands are not needed.

   # Load iptables module:
   # modprobe ip_tables

   # activate connection tracking
   # (connection's status are taken into account)
   # modprobe ip_conntrack

   # Special features for IRC:
   # modprobe ip_conntrack_irc

   # Special features for FTP:
   # modprobe ip_conntrack_ftp

   # Deleting all the rules in INPUT, OUTPUT and FILTER   
   # iptables --flush

   # Flush all the rules in nat table 
   # iptables --table nat --flush

   # Delete all existing chains
   # iptables --delete-chain

   # Delete all chains that are not in default filter and nat table
   # iptables --table nat --delete-chain

   iptables -t nat -A POSTROUTING -o $INTERNET -j MASQUERADE --random
   
   # Allow traffic from internal to external
   iptables -A FORWARD -i $LOCAL -o $INTERNET -j ACCEPT
   
   # Allow returning traffic from external to internal
   iptables -A FORWARD -i $INTERNET -o $LOCAL -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
   
   # Drop all other traffic that shouldn't be forwarded
   iptables -A FORWARD -j DROP
   
