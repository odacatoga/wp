#!/bin/bash
# By Tra Viet
# Selinux and Firewall turn off before run this

#Set Time
timedatectl set-timezone Asia/Ho_Chi_Minh
timedatectl set-ntp 1

# Change hostname
sed -i '2d' /etc/hosts
sed -i '2 i 127.0.1.1       dp' /etc/hosts
hostnamectl set-hostname dp

# Statics Ip set up
sed -i '5d' /etc/netplan/00-installer-config.yaml
sed -i '5 i \      addresses:' /etc/netplan/00-installer-config.yaml
sed -i '6 i \      - 10.10.200.155/24' /etc/netplan/00-installer-config.yaml
sed -i '7 i \      gateway4: 10.10.200.1' /etc/netplan/00-installer-config.yaml
sed -i '8 i \      nameservers:' /etc/netplan/00-installer-config.yaml
sed -i '9 i \        addresses:' /etc/netplan/00-installer-config.yaml
sed -i '10 i \        - 8.8.8.8' /etc/netplan/00-installer-config.yaml
sed -i '11 i \        - 10.10.100.100' /etc/netplan/00-installer-config.yaml
sed -i '12 i \        - 10.10.100.101' /etc/netplan/00-installer-config.yaml

sudo netplan apply

sleep 3

 MariaDB
sudo apt update
sudo apt install software-properties-common -y
curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=10.7
sudo bash mariadb_repo_setup --mariadb-server-version=10.7
sudo apt update
sudo apt -y install mariadb-common mariadb-server mariadb-client
sudo systemctl enable mariadb
sudo systemctl start mariadb


sleep 3

# Type Y/n follow the question below
mysql_secure_installation <<EOF
y
y
wp@fptgroup
wp@fptgroup
y
y
y
y
EOF
mysql -u root -p <<EOF
create database wordpress character set utf8 collate utf8_unicode_ci;
grant all privileges on wordpress.* to wordpress@localhost identified by 'wp@fptgroup';
grant all privileges on wordpress.* to wordpress@10.10.200.153 identified by 'wp@fptgroup';
grant all privileges on wordpress.* to wordpress@10.10.200.154 identified by 'wp@fptgroup';
Flush Privileges;
exit
EOF

sed -i 's/bind-address            = 127.0.0.1/bind-address            = 0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf

sudo systemctl restart mariadb

# Download Zabbix Agent
sudo wget https://repo.zabbix.com/zabbix/6.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.2-4%2Bubuntu22.04_all.deb
sudo dpkg -i zabbix-release_6.2-4+ubuntu22.04_all.deb
sudo apt update

sleep 2

# Install Zabbix Agent
sudo apt install zabbix-agent -y
systemctl enable zabbix-agent
systemctl restart zabbix-agent

sleep 3

# Configure Agent point to Zabbix Server
sed -i 's/Server=127.0.0.1/Server=10.10.200.161/g' /etc/zabbix/zabbix_agentd.conf
sed -i 's/ServerActive=127.0.0.1/ServerActive=10.10.100.161/g' /etc/zabbix/zabbix_agentd.conf
sed -i 's/Hostname=Zabbix server/Hostname=wp.fptgroup.com/g' /etc/zabbix/zabbix_agentd.conf
sed -i 's/# HostMetadata=/HostMetadata=LinuxServer/g' /etc/zabbix/zabbix_agentd.conf
#sed -i 's/# HostMetadata=/HostMetadata=WindowsServer/g' /etc/zabbix/zabbix_agentd.conf

sudo ufw allow proto tcp from any to any port 80,443,22
sudo ufw allow proto tcp from 10.10.100.161 to any port 10050,10051
sudo ufw allow proto tcp from 10.10.100.162 to any port 9115
sudo ufw allow proto tcp from 10.10.100.162 to any port 9100
sudo ufw allow proto tcp from 10.10.200.153 to any port 3306
sudo ufw allow proto tcp from 10.10.200.154 to any port 3306
sudo ufw enable

#
sudo passwd user <<EOF
Fpt@@123
Fpt@@123
EOF

cd

rm -rf wp
