#!/bin/bash
# By Tra Viet
# Selinux and Firewall turn off before run this

#Set Time
timedatectl set-timezone Asia/Ho_Chi_Minh
timedatectl set-ntp 1

# Change hostname
sed -i '2d' /etc/hosts
sed -i '3 i 127.0.1.1       wp.fptgroup.com' /etc/hosts
sed -i '4 i 10.10.200.153   wp.fptgroup.com' /etc/hosts
hostnamectl set-hostname wp

# Statics Ip set up
sed -i '5d' /etc/netplan/00-installer-config.yaml
sed -i '5 i \      addresses:' /etc/netplan/00-installer-config.yaml
sed -i '6 i \      - 10.10.200.153/24' /etc/netplan/00-installer-config.yaml
sed -i '7 i \      gateway4: 10.10.200.1' /etc/netplan/00-installer-config.yaml
sed -i '8 i \      nameservers:' /etc/netplan/00-installer-config.yaml
sed -i '9 i \        addresses:' /etc/netplan/00-installer-config.yaml
sed -i '10 i \        - 8.8.8.8' /etc/netplan/00-installer-config.yaml
sed -i '11 i \        - 10.10.100.100' /etc/netplan/00-installer-config.yaml
sed -i '12 i \        - 10.10.100.101' /etc/netplan/00-installer-config.yaml

sudo netplan apply

sleep 5

# Update && Upgrade Ubuntu
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl network-manager net-tools apt-transport-https openssl -y

sleep 3

# Apache2 Install
sudo apt install apache2 apache2-utils -y
sudo systemctl enable apache2
sudo systemctl start apache2


# PHP Intall

sudo apt install -y php php-{common,mysql,xml,xmlrpc,curl,gd,imagick,cli,dev,imap,mbstring,opcache,soap,zip,intl}

# SSL
sed -i '395 i [ wp.fptgroup.com ]' /etc/ssl/openssl.cnf
sed -i '396 i subjectAltName = DNS:wp.fptgroup.com' /etc/ssl/openssl.cnf

sleep 3
openssl genrsa -aes128 2048 > /etc/ssl/private/wp.key
openssl rsa -in /etc/ssl/private/wp.key -out /etc/ssl/private/wp.key
openssl req -utf8 -new -key /etc/ssl/private/wp.key -out /etc/ssl/private/wp.csr << EOF

VN
Ho Chi Minh
Ho Chi Minh
FPTGroup
wp
wp.fptgroup.com
admin@fptgroup.com
wpfptgroup
FPTGroup
EOF

openssl x509 -in /etc/ssl/private/wp.csr -out /etc/ssl/private/wp.crt -req -signkey /etc/ssl/private/wp.key -extfile /etc/ssl/openssl.cnf -extensions wp.fptgroup.com -days 3650
chmod 644 /etc/ssl/private/wp.key

sudo chown www-data:www-data -R /etc/ssl/private/wp.crt
sudo chown www-data:www-data -R /etc/ssl/private/wp.key
sleep 3

# Install Wordpress
sudo apt install wget unzip -y
wget https://wordpress.org/latest.zip
sudo unzip latest.zip
sudo mv wordpress/ /var/www/html/
sudo rm latest.zip

sleep 3
cat /var/www/html/wordpress/wp-config-sample.php >> /var/www/html/wordpress/wp-config.php
sed -i "s/define( 'DB_NAME', 'database_name_here' );/define( 'DB_NAME', 'wordpress' );/g" /var/www/html/wordpress/wp-config.php
sed -i "s/define( 'DB_USER', 'username_here' );/define( 'DB_USER', 'wordpress' );/g" /var/www/html/wordpress/wp-config.php
sed -i "s/define( 'DB_PASSWORD', 'password_here' );/define( 'DB_PASSWORD', 'wp@fptgroup' );/g" /var/www/html/wordpress/wp-config.php
sed -i "s/define( 'DB_HOST', 'localhost' );/define( 'DB_HOST', '10.10.200.155' );/g" /var/www/html/wordpress/wp-config.php

sudo chown www-data:www-data -R /var/www/html/wordpress/
sudo chmod -R 755 /var/www/html/wordpress/

sleep 3

sudo cat << EOF > /etc/apache2/sites-available/wp.fptgroup.com.conf 
<VirtualHost *:80> 
    ServerName wp.fptgroup.com
    ServerAlias www.wp.fptgroup.com
    Redirect permanent / https://wp.fptgroup.com
</VirtualHost>

<VirtualHost *:443>

    ServerName wp.fptgroup.com
    ServerAlias www.wp.fptgroup.com
    ServerAdmin admin@wp.fptgroup.com
    DocumentRoot /var/www/html/wordpress

    ErrorLog ${APACHE_LOG_DIR}/www.wp.fptgroup.com_error.log
    CustomLog ${APACHE_LOG_DIR}/www.wp.fptgroup.com_access.log combined

    SSLEngine on
    SSLCertificateFile /etc/ssl/private/wp.crt
    SSLCertificateKeyFile /etc/ssl/private/wp.key

   <Directory /var/www/html/wordpress/*>
      Options FollowSymlinks
      AllowOverride All
      Require all granted
      DirectoryIndex index.php
   </Directory>

</VirtualHost>
EOF

Sleep 3
a2enmod ssl
sudo a2enmod rewrite
sudo a2ensite wp.fptgroup.com.conf
sudo a2dissite 000-default.conf
sudo systemctl restart apache2

# Download Zabbix Agent
sudo wget https://repo.zabbix.com/zabbix/6.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.2-4%2Bubuntu22.04_all.deb
sudo dpkg -i zabbix-release_6.2-4+ubuntu22.04_all.deb
sudo apt update

sleep 2

# Install Zabbix Agent
sudo apt install zabbix-agent
systemctl enable zabbix-agent
systemctl restart zabbix-agent

sleep 3

# Configure Agent point to Zabbix Server
sed -i 's/Server=127.0.0.1/Server=10.10.100.161/g' /etc/zabbix/zabbix_agentd.conf
sed -i 's/ServerActive=127.0.0.1/ServerActive=10.10.100.161/g' /etc/zabbix/zabbix_agentd.conf
sed -i 's/Hostname=Zabbix server/Hostname=wp.fptgroup.com/g' /etc/zabbix/zabbix_agentd.conf
sed -i 's/# HostMetadata=/HostMetadata=LinuxServer/g' /etc/zabbix/zabbix_agentd.conf
systemctl restart zabbix-agent

#
sudo ufw allow proto tcp from any to any port 80,443,22
sudo ufw allow proto tcp from 10.10.100.161 to any port 10050,10051
sudo ufw allow proto tcp from 10.10.200.155 to any port 3306
sudo ufw enable

sudo passwd user <<EOF
Fpt@@123
Fpt@@123
EOF

cd

rm -rf wp
