#! /bin/bash

help()
{
  echo "sap_setup.sh -s "RPI_SAP" -p "RPI@12345" -c "IN" -i "wlan0""
}

while getopts "s:p:c:i:h" option; do
  case $option in
    s | ssid)
       sap_ssid=${OPTARG};;
    p | password)
       passphrase=${OPTARG};;
    c | countrycode)
       sap_cc=${OPTARG};;
    i | if)
       if=${OPTARG};;
    h) help
       exit;;
    esac
done

echo $sap_ssid $passphrase $sap_cc $if
echo "Setting up Soft AP setup in RPI"

sudo apt-get update
sudo apt-get install hostapd dnsmasq iptables-persistent

#if=$4
echo $if
sap_channel="$(iwlist $if channel | grep 'Current Frequency:' | awk -F '(' '{gsub("\)", "", $2); print $2}' | awk -F ' ' '{print $2}')"
#sap_ssid=$1
sap_if="sap0"
#sap_cc=$3
#passphrase=$2
echo  $sap_cc $sap_if $sap_ssid $sap_channel
sudo mkdir -p /etc/hostapd
sudo touch /etc/hostapd/hostapd.conf
sudo cat > /etc/hostapd/hostapd.conf <<EOF
channel=$sap_channel
ssid=$sap_ssid
country_code=$sap_cc
interface=$sap_if
hw_mode=g
wpa_passphrase=$passphrase
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
macaddr_acl=0
EOF

sta_config_file="/etc/network/interfaces.d/wlan0"
cat > $sta_config_file <<EOF
allow-hotplug ${if}
EOF

sap_config_file="/etc/network/interfaces.d/sap0"
cat > $sap_config_file <<EOF
allow-hotplug ${sap_if}
auto ${sap_if}
iface sap0 inet static
    address 192.168.0.2
    netmask 255.255.255.0
EOF

echo 'interface=lo,sap0
no-dhcp-interface=lo,wlan0
bind-interfaces
server=8.8.8.8
dhcp-range=192.168.0.2,192.168.0.102,12h' | tee /etc/dnsmasq.conf

echo 'interface sap0
    static ip_address=192.168.0.1
    nohook wpa_supplicant' | tee -a /etc/dhcpcd.conf

echo 'auto lo
    iface lo inet loopback
    iface eth0 inet manual
    source-directory /etc/network/interfaces.d' | tee /etc/network/interfaces

sudo echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' | sudo tee  /etc/default/hostapd

sed '/exit 0/d' /etc/rc.local > ./tmp.conf
echo "/bin/bash $PWD/sap_start.sh
exit 0" >> ./tmp.conf
rm -f /etc/rc.local
mv ./tmp.conf /etc/rc.local
rm -f ./tmp.conf

sudo systemctl unmask hostapd.service
sudo chmod ug+x /etc/rc.local
