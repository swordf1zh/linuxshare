#!/bin/bash

# Installing Samba
echo "Installing Samba..."
sudo apt-get update -y > /dev/null
sudo apt-get install -y samba > /dev/null

# Stopping services and disabling netbios
sudo systemctl stop nmbd.service
sudo systemctl disable nmbd.service
sudo systemctl stop smbd.service
echo "Done!"
echo

# Firewall setup
echo
read -p 'Do you want to setup firewall rules? (y/n) ' -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  read -p 'What IP do you want to allow access to your share? ' ALLOWIP
  
  if [ -z "$ALLOWIP" ]
  then
    echo "No IP provided. Skipping firewall setup."
  else
    # Allow SSH if connected through SSH to avoid connection disruption
    [ -z "$SSH_CLIENT" ] || ufw allow OpenSSH
    ufw allow from "$ALLOWIP" to any app Samba
    ufw enable
    ufw status
  fi
  echo "Done!"
  echo
fi

# SAMBA CONFIG
echo "Setting Samba..."

# Backup original conf file
cp /etc/samba/smb.conf{,.bak}

echo
read -p 'Server name: ' SERVERNAME
echo

INTERFACES=$(ifconfig | grep flags | awk -F: '{ print $1 }' | tr '\n' ' ')

(
cat <<EOF
[global]
        server string = $SERVERNAME
        server role = standalone server
        interfaces = $INTERFACES
        bind interfaces only = yes
        disable netbios = yes
        smb ports = 445
        log file = /var/log/samba/smb.log
        log level = 3 passdb:5 auth:5
        max log size = 10000

[$USER]
        path = /home/$USER
        browseable = no
        read only = no
        valid users = $USER
EOF
) > /etc/samba/smb.conf

# Verifying setup
testparm

# Setting user in Samba
usermod -a -G sambashare "$USER"
sudo smbpasswd -a "$USER"
sudo smbpasswd -e "$USER"

echo "Done!"
echo

# Starting Samba service
echo "Starting samba service..."
sudo systemctl start smbd.service

SRVIP=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
echo "Done! You should be able to access the shared folder at \\\\$SRVIP\\$USER"
echo "=)"