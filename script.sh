#!/bin/bash
# Set DEBIAN_FRONTEND to noninteractive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Use 'sudo' to execute it."
    exit 1
fi

# Check if ocserv has already been set up
if systemctl is-active --quiet ocserv; then
    echo "You have already set up the configurations."
    exit 0
fi

# Default values
DOMAIN=""
EMAIL=""
OCUSER=""
OCPASS=""

# Function to display usage
usage() {
    echo "Usage: $0 -d <domain_name> -e <email> -u <username> -p <password>"
    exit 1
}

# Parse command-line options
while getopts "d:e:u:p:" opt; do
    case "$opt" in
        d) DOMAIN="$OPTARG" ;;
        e) EMAIL="$OPTARG" ;;
        u) OCUSER="$OPTARG" ;;
        p) OCPASS="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check for missing arguments
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ] || [ -z "$OCUSER" ] || [ -z "$OCPASS" ]; then
    usage
fi

# Update the system
apt update
apt upgrade -y

# Install necessary packages
apt install ocserv certbot gnutls-bin -y

# Run ldconfig to update library paths
sudo ldconfig

# Request a Let's Encrypt certificate
certbot certonly --standalone --non-interactive --agree-tos --email $EMAIL -d $DOMAIN

# Configure ocserv with GnuTLS settings
cp /etc/ocserv/ocserv.conf /etc/ocserv/ocserv.conf.bak

cat <<EOF > /etc/ocserv/ocserv.conf
auth = "plain[passwd=/etc/ocserv/ocpasswd]"
try-mtu-discovery = true
dns = 1.1.1.1
dns = 8.8.8.8
tunnel-all-dns = true
server-cert = /etc/letsencrypt/live/$DOMAIN/fullchain.pem
server-key = /etc/letsencrypt/live/$DOMAIN/privkey.pem
ipv4-network = 192.168.2.1/24
max-clients = 128
max-same-clients = 4
no-route = 192.168.5.0/255.255.255.0
debug = true
debug-min = 2
socket-file = /run/ocserv.socket
tcp-port = 443
keepalive = 300
try-mtu-discovery = true
auth-timeout = 240
device = vpn0

mtu = 1400

output-buffer = 23000
cisco-client-compat = true
dtls-legacy = true

# GnuTLS Configuration
tls-priorities = "NORMAL:%SERVER_PRECEDENCE:%COMPAT:-VERS-SSL3.0"
EOF

# Create ocserv user
echo "$OCPASS" | ocpasswd -c /etc/ocserv/ocpasswd "$OCUSER"

# Start and enable the ocserv service
systemctl enable ocserv
systemctl start ocserv

# Add iptables rules
iptables -I INPUT -p tcp --dport 22 -j ACCEPT
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -p udp --dport 443 -j ACCEPT
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -I FORWARD -d 192.168.2.0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 192.168.2.0 -j ACCEPT

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Save and apply iptables rules
iptables-save > /etc/iptables/rules.v4
systemctl enable netfilter-persistent
systemctl start netfilter-persistent

# Restart the ocserv service
systemctl restart ocserv

# Display server setup completion message
echo "Your OpenConnect server is set up and running."
echo "Please check the ocserv logs with: journalctl -u ocserv"
