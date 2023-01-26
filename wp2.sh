#!/bin/bash
# By Tra Viet
# Selinux and Firewall turn off before run this

#Set Time
timedatectl set-timezone Asia/Ho_Chi_Minh
timedatectl set-ntp 1

# Change hostname
sed -i '2d' /etc/hosts
sed -i '3 i 127.0.1.1       wp.fptgroup.com' /etc/hosts
sed -i '4 i 10.10.200.154   wp.fptgroup.com' /etc/hosts
hostnamectl set-hostname wp

# Statics Ip set up
sed -i '5d' /etc/netplan/00-installer-config.yaml
sed -i '5 i \      addresses:' /etc/netplan/00-installer-config.yaml
sed -i '6 i \      - 10.10.200.154/24' /etc/netplan/00-installer-config.yaml
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
chmod 600 /etc/ssl/private/wp.key

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

sleep 3

# Prometheus Node Exporter
# Download and Extract
wget https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz
tar -xvf node_exporter-1.5.0.linux-amd64.tar.gz

# Node Exporter
useradd -rs /bin/false node_exporter
mkdir -p /etc/node_exporter/cert
mv node_exporter-1.5.0.linux-amd64/node_exporter /usr/local/bin
chown -R node_exporter:node_exporter /usr/local/bin/node_exporter /etc/node_exporter/*
chown -R node_exporter:node_exporter /etc/node_exporter/*

# Configurage
 cat << EOF >/etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target
[Service]
Type=simple
User=node_exporter
Group=node_exporter
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/node_exporter
SyslogIdentifier=node_exporter
Restart=always
[Install]
WantedBy=default.target
EOF

rm -rf node_exporter-1.5.0.linux-amd64.tar.gz node_exporter-1.5.0.linux-amd64

# Turn on
systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

#SSL Node_Exporter

openssl genrsa -aes128 2048 > /etc/ssl/private/node_exporter.key
openssl rsa -in /etc/ssl/private/node_exporter.key -out /etc/ssl/private/node_exporter.key
openssl req -utf8 -new -key /etc/ssl/private/node_exporter.key -out /etc/ssl/private/node_exporter.csr << EOF

VN
Ho Chi Minh
Ho Chi Minh
FPTGroup
node_exporter
wp.fptgroup.com
node_exporter@fptgroup.com
wpfptgroup
FPTGroup
EOF

openssl x509 -in /etc/ssl/private/node_exporter.csr -out /etc/ssl/private/node_exporter.crt -req -signkey /etc/ssl/private/node_exporter.key -extfile /etc/ssl/openssl.cnf -extensions wp.fptgroup.com -days 3650
chmod 644 /etc/ssl/private/node_exporter.key /etc/ssl/private/node_exporter.crt
sudo cp -a /etc/ssl/private/node_exporter.crt /etc/ssl/private/node_exporter.key /etc/node_exporter/cert
sudo chown node_exporter:node_exporter /etc/node_exporter/cert/node_exporter.key
sudo chown node_exporter:node_exporter /etc/node_exporter/cert/node_exporter.crt


mkdir -p /etc/apache2/htpasswd/
htpasswd -cB /etc/apache2/htpasswd/node_exporter admin
cat << EOF > /etc/node_exporter/web.yml
# create new
# specify your certificate
tls_server_config:
  cert_file: /etc/node_exporter/cert/node_exporter.crt
  key_file: /etc/node_exporter/cert/node_exporter.key

# specify username and password generated above
basic_auth_users:
EOF

sed -i 10's/$/ --web.config.file=\/etc\/node_exporter\/web.yml &/' /etc/systemd/system/node_exporter.service
sed -n '1p' /etc/apache2/htpasswd/node_exporter >> /etc/node_exporter/web.yml
sed -i 's/admin:/\        admin: /' /etc/node_exporter/web.yml

sleep 3

sudo systemctl daemon-reload
sudo systemctl restart node_exporter.service
#
sudo ufw allow proto tcp from any to any port 80,443,22
sudo ufw allow proto tcp from 10.10.100.161 to any port 10050,10051
sudo ufw allow proto tcp from 10.10.100.162 to any port 9100
sudo ufw allow proto tcp from 10.10.200.155 to any port 3306
sudo ufw enable

sudo passwd user <<EOF
Fpt@@123
Fpt@@123
EOF

cd

rm -rf wp
