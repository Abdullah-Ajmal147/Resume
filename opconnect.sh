#!/bin/bash
apt install curl -y;
apt install sudo -y;
apt install zip unzip -y;
sudo curl -L -o /root/ocserv https://www.dropbox.com/s/7pdxknot5c5xub5/0.12.6?dl=0
mv /root/ocserv /usr/sbin/ocserv
chmod 777 /usr/sbin/ocserv;
echo "Copying Scripts"; 
curl -L -o scripts.zip https://www.dropbox.com/s/akafdrfwlmvx45x/scripts.zip?dl=0;
unzip scripts.zip;
mkdir /etc/ocserv/...
chmod 777 /etc/ocserv/...
mv connect /etc/ocserv/.../...
mv disconnect /etc/ocserv/.../....
mv periodic /etc/ocserv/.../.....
chmod 777 /etc/ocserv/.../...
chmod 777 /etc/ocserv/.../....
chmod 777 /etc/ocserv/.../.....
if grep -Fxq  "www-data ALL=(ALL) NOPASSWD:ALL" /etc/sudoers; then
echo "Skippping...."; else
echo "www-data ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; fi
curl -L -o /var/www/html/online.php https://www.dropbox.com/s/hekcbc0x78lpaaq/online.php?dl=0
chown root:root /usr/sbin/occtl
chown root:root /var/www/html/online.php
chmod 755 /usr/sbin/occtl
chmod 755 /var/www/html/online.php
echo "Writing Configurations"
IP=$(curl ifconfig.me);
if grep -Fxq "host-ssl-enabled = 1" /etc/ocserv/ocserv.conf; then
echo "Skippping...."; else
echo "host-ssl-enabled = 1" >> /etc/ocserv/ocserv.conf; fi

if grep -Fxq "host-link = onionvpn.net" /etc/ocserv/ocserv.conf; then
echo "Skippping...."; else
echo "host-link = onionvpn.net" >> /etc/ocserv/ocserv.conf; fi

if grep -Fxq "host-page = connection" /etc/ocserv/ocserv.conf; then
echo "Skippping...."; else
echo "host-page = connection" >> /etc/ocserv/ocserv.conf; fi

if grep -Fxq "user-api = username" /etc/ocserv/ocserv.conf; then
echo "Skippping...."; else
echo "user-api = username" >> /etc/ocserv/ocserv.conf; fi

if grep -Fxq "password-api = password" /etc/ocserv/ocserv.conf; then
echo "Skippping...."; else
echo "password-api = password" >> /etc/ocserv/ocserv.conf; fi

if grep -Fxq "server-api = ip" /etc/ocserv/ocserv.conf; then
echo "Skippping...."; else
echo "server-api = ip" >> /etc/ocserv/ocserv.conf; fi

if grep -Fxq "proc-api = proc" /etc/ocserv/ocserv.conf; then
echo "Skippping...."; else
echo "proc-api = proc" >> /etc/ocserv/ocserv.conf; fi

if grep -Fxq "ip = $IP" /etc/ocserv/ocserv.conf; then
echo "Skippping...."; else
echo "ip = $IP" >> /etc/ocserv/ocserv.conf; fi

if grep -Fxq "#connect-script = /etc/ocserv/.../..." /etc/ocserv/ocserv.conf; then
echo "Skippping...."; else
echo "#connect-script = /etc/ocserv/.../..." >> /etc/ocserv/ocserv.conf; fi

if grep -Fxq "#disconnect-script = /etc/ocserv/.../...." /etc/ocserv/ocserv.conf; then
echo "Skippping...."; else
echo "#disconnect-script = /etc/ocserv/.../...." >> /etc/ocserv/ocserv.conf; fi

systemctl restart ocserv;
echo "Flushing";
#rm -r /root/ocserv* /root/*.sh /root/*.zip

#sudo rm -f /cd/var/log/messages.*
#cat /dev/null > ~/.bash_history && history -c
history -c

echo "Exiting"
exit 0;
