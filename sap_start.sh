#! /bin/bash

echo "Removing sap0 interface..."
iw dev sap0 del

#Add sap0 interface
echo "Adding sap0 interface..."
iw dev wlan0 interface add sap0 type __ap

#Modify iptables
echo "IPV4 forwarding for bridge mode"
sed -i 's/^#net.ipv4.ip_forward=.*$/net.ipv4.ip_forward=1/' /etc/sysctl.conf
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -F
iptables -t nat -F
sleep 2
iptables -t nat -A POSTROUTING -s 192.168.0.0/16 ! -d 192.168.0.0/16 -j MASQUERADE
iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
iptables -A FORWARD -i wlan0 -o sap0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i sap0 -o wlan0 -j ACCEPT
#iptables-save > /etc/iptables/rules.v4
#iptables-save > /etc/iptables.ipv4.nat
#iptables-restore < /etc/iptables.ipv4.nat

ifconfig sap0 up

sleep 10

echo "Starting hostapd service..."
systemctl start hostapd.service
sleep 10

echo "Starting dhcpcd service..."
systemctl start dhcpcd.service
sleep 20

echo "Starting dnsmasq service..."
systemctl restart dnsmasq.service
