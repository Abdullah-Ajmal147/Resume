#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Parse command line arguments
while getopts "s:" opt; do
  case ${opt} in
    s )
      radius_server_ip=$OPTARG
      ;;
    \? )
      echo "Usage: $0 -s radius_server_ip"
      exit 1
      ;;
  esac
done

# Check if radius_server_ip is provided
if [ -z "$radius_server_ip" ]; then
  echo "Please provide the RADIUS server IP using -s option."
  exit 1
fi

# Define EasyRSA version for easy updates
EASYRSA_VERSION="3.0.1"

# Update package list and install OpenVPN and Easy-RSA
apt-get update
apt-get install -y openvpn easy-rsa iptables-persistent nginx freeradius

# Download and verify EasyRSA
wget -O ~/EasyRSA-$EASYRSA_VERSION.tgz "https://github.com/OpenVPN/easy-rsa/releases/download/$EASYRSA_VERSION/EasyRSA-$EASYRSA_VERSION.tgz"
# Add checksum verification here (Optional)

# Extract EasyRSA and set permissions
tar xzf ~/EasyRSA-$EASYRSA_VERSION.tgz -C /etc/openvpn/
mv /etc/openvpn/EasyRSA-$EASYRSA_VERSION/ /etc/openvpn/easy-rsa/
chown -R root:root /etc/openvpn/easy-rsa/
rm ~/EasyRSA-$EASYRSA_VERSION.tgz

# Initialize Easy-RSA and build CA
cd /etc/openvpn/easy-rsa/
./easyrsa init-pki
./easyrsa --batch build-ca nopass
./easyrsa gen-dh
./easyrsa build-server-full server nopass
./easyrsa gen-crl

# Move necessary files and set correct permissions
cp pki/ca.crt pki/private/ca.key pki/dh.pem pki/issued/server.crt pki/private/server.key pki/crl.pem /etc/openvpn/
chown nobody:nogroup /etc/openvpn/crl.pem

# Generate key for tls-auth
openvpn --genkey --secret /etc/openvpn/ta.key

# Get the server IP Address
IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
if [[ "$IP" = "" ]]; then
    IP=$(wget -4qO- "http://whatismyip.akamai.com/")
    if [[ "$IP" = "" ]]; then
        IP=$(wget -4qO- "http://ipecho.net/plain")
    fi
fi
# File path for the authentication script
auth_script_path="/etc/openvpn/auth_script.sh"

# Contents of the authentication script
auth_script_content="#!/bin/bash

# Script to authenticate against FreeRADIUS using radtest

# Path to the temporary file is passed as the first argument
credentials_file=\"\$1\"

# Read username and password from the file
username=\$(awk 'NR==1' \$credentials_file)
password=\$(awk 'NR==2' \$credentials_file)

# RADIUS server details
radius_server=\"$radius_server_ip\"
radius_secret=\"newSecretForVpnserver1\"
radius_port=\"1812\"  # Default RADIUS port for authentication

# Send request to RADIUS server using radtest
response=\$(radtest \"\$username\" \"\$password\" \$radius_server \$radius_port \$radius_secret)

# Check response
if echo \"\$response\" | grep -q \"Access-Accept\"; then
    exit 0  # Authentication successful
else
    exit 1  # Authentication failed
fi"

# Create the authentication script file
echo "$auth_script_content" > "$auth_script_path"

# Give read and write permissions to the script
chmod +x "$auth_script_path"


# Create server configuration with secure defaults
cat > /etc/openvpn/server.conf <<EOF
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-CBC
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
log /var/log/openvpn.log
status /var/log/openvpn-status.log
verb 6
explicit-exit-notify 1
#plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login
auth-user-pass-verify /etc/openvpn/auth_script.sh via-file
script-security 2

--verify-client-cert none
username-as-common-name
EOF

# Enable IP forwarding
sed -i '/net.ipv4.ip_forward=1/s/^#//g' /etc/sysctl.conf
sysctl -p

# Set up iptables for NAT and forwarding with comments for clarity
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
iptables -A INPUT -p udp --dport 1194 -j ACCEPT
iptables -A OUTPUT -p udp --sport 1194 -j ACCEPT
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -j ACCEPT

# Save iptables rules
netfilter-persistent save

# Create client configuration directory
mkdir -p /etc/openvpn/client

# Set up the client configuration file with secure defaults
cat > /etc/openvpn/client/client.ovpn <<EOF
client
dev tun
proto udp
remote $IP 1194 
resolv-retry infinite
nobind
persist-key
persist-tun
auth-user-pass
remote-cert-tls server
cipher AES-256-CBC
auth SHA256
verb 3
<ca>
EOF

# Append the CA certificate to the client configuration file
cat /etc/openvpn/ca.crt >> /etc/openvpn/client/client.ovpn
echo '</ca>' >> /etc/openvpn/client/client.ovpn

# Restart and enable OpenVPN service
systemctl restart openvpn@server
systemctl enable openvpn@server

echo "OpenVPN setup is complete. Use /etc/openvpn/client/client.ovpn for client configurations."

# Setup Nginx to serve the client.ovpn file
cp /etc/openvpn/client/client.ovpn /var/www/html/
cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Restart Nginx to apply changes
systemctl restart nginx

echo "OpenVPN setup is complete. Access your client configuration at http://$IP/client.ovpn"