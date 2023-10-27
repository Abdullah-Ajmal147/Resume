#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Check for required arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 yourdomain.com youremail@gmail.com"
    exit 1
fi

DOMAIN=$1
EMAIL=$2

# Ensure port 80 is free. `certbot` standalone needs it for verification.
# You might need to temporarily stop your web server if it's using this port.
sudo fuser -k 80/tcp

# Update the system and install necessary packages
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:certbot/certbot -y
sudo apt update
sudo apt install -y certbot 

# Obtain the SSL certificate using standalone mode
sudo certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --email $EMAIL

echo "SSL certificate has been installed. You can find the certificate and key at:"
echo "/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
echo "/etc/letsencrypt/live/$DOMAIN/privkey.pem"

