#!/bin/bash
#
# Created:      05-June-2016
# Author:       EJK
# Description:
#
# A short post installation utility script to set up a Web Service server on a private
# network within SoftLayer. This file can be executed standalone or implemented as part 
# of a post installation script. The script itself does the following:
# 
# - creates a logfile so we can debug;
# - carries out a yum update;
# - adds a 'sysadm' user;
# - adds the 'sysadm' user to sudoers file;
# - adds the 'sysadm' ssh keys;
# - restarts ssh daemon;
# - sets the timezone correctly;
# - yum installs the graphical packages to enable X usage by administrators;
# - yum installs the group of Development Tools;
# - resets the inittab to boot to graphical;
# - installs firefox browser;
# - installs the apache server;
# - installs the required SSL packages;
# - generates a private key;
# - generates the certificate signing request;
# - generates the self signed key; 
# - copies the keys to the right place;
# - edits the apache configuration to point ot the new key; and
# - restarts apache. 
#
# Dependencies:
# 1) A SoftLayer account;
# 2) Assumes CentOS 6 operating system;
# 3) Assumes a minimal build.
#
# License: MIT License
# Copyright (c)2016, SaaSify Limited, EJK
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
# associated documentation files (the "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
# following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial
# portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
# LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
# NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# ----------------------------------------------------------------------------------------
#
#                                    SCRIPT STARTS
#
# ----------------------------------------------------------------------------------------
#
# Script Variables
#
# From a change control perspective this script is set up in such a way that simply changing
# these variables will deliver the changes without having to change the structure of the
# bash script itself.
#

LOGFILE="logs/makewebservice.log"
sysadmuid="968"
sysadmuser="sysadm"

#
# Lets create a log of the install
#

mkdir logs
exec > >(tee -i $LOGFILE)
exec 2>&1

#
# Lets quickly update the yum repositories
#

echo "********************************************************************************" 
echo "*                              executing Yum Update                            *" 
echo "********************************************************************************" 

yum -y update

#
# Add the standard administration user for L&G machines on SoftLayer. Given we're using
# images as part of the build we need to be sure we maintain consistency over the uid and
# trusted keys that get implemented on new machines. To do this we need to eradicate any
# existing standard Systems Administration user that may be contained in the image file.
#

echo "********************************************************************************" 
echo "*                              adding 'sysadm' user                            *" 
echo "********************************************************************************" 

id -u $sysadmuser > /dev/null
if [ $? == 1 ]; then
   useradd $sysadmuser -u $sysadmuid -c "Standard Systems Administration User" -m
else
   userdel -r $sysadmuser
   useradd $sysadmuser -u $sysadmuid -c "Standard Systems Administration User" -m
fi

#
# Add a password for the administration user - clearly this is suboptimal and the future
# trajectory for this aspect is to add a standard administrative user to LDAP and to
# manage the password distribution through that mechanism. For expediency in the POC
# the password is set here. That said this script is removing the ability to SSH into
# accounts using passwords so security integrity is maintained. Only access to the console
# would enable the use of this password.
#

passwd sysadm <<EOT
t5QMF;{/rP>aW/c6
t5QMF;{/rP>aW/c6
EOT

#
# We need to add the standard Systems Administrator account to the sudoers file
#

echo "sysadm    ALL=(ALL)       NOPASSWD:ALL" >> /etc/sudoers

#
# We need to add the trusted keys file into the .ssh directory of the standard Syatems
# Administration users home directory.
#

mkdir /home/sysadm/.ssh
chown sysadm /home/sysadm/.ssh
chmod 700 /home/sysadm/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJApotnI8z+jw8qIlfmE6HdKrb1SjvXsenAlvhM73DtuQtXnM2Wc3nxi3pAmdWQPsXBmsWaohKu6rXqY8KMEH8eRxEjaVxyi8qOgWVwtXRHvo+l5BHrzETDQSjxAHi98DYAnOx4tx6qhpXNfACepbBh0vzTfhZ6UPff6hpNk9jnm9NS9EC7BRhxz7CJmCdPYfcq0xLV+mnLNemG9z2evEXQytXMvhGw1ekeUViCsgt6ceKbVkKSHRWcIL2De4EE8pCnZyK2Ac33nm4HCF65QJP0QUHrE+9Ga+KJrqfXqLylg17WS70Qk5u6d1jf23gsEltMmH5ckCjfPzsHzaC06SJ saasify@Eamonns-iMac.local" > /home/sysadm/.ssh/authorized_keys
chown sysadm /home/sysadm/.ssh/authorized_keys
chmod 600 /home/sysadm/.ssh/authorized_keys

#
# Restart the ssh service
#

service sshd restart

#
# Link the timezone correctly
#

rm -rf /etc/localtime
ln -s /usr/share/zoneinfo/Europe/London /etc/localtime

echo "********************************************************************************" 
echo "*                         Installing the Graphics Packages                     *"
echo "********************************************************************************"

yum -y groupinstall "X Window System"
yum -y groupinstall "Development tools"
yum -y groupinstall "Desktop" "Desktop Platform" "Fonts"
yum -y groupinstall "Graphical Administration Tools"
sed -i "s/id:3/id:5/g" /etc/inittab
yum -y install xterm
yum -y install firefox

echo "********************************************************************************"
echo "*                           Installing the Apache Packages                     *"
echo "********************************************************************************" 

yum -y install httpd
chkconfig httpd on
service httpd start

echo "********************************************************************************" 
echo "*                       Implementing a self-signed certificate                 *" 
echo "********************************************************************************" 

yum -y install mod_ssl openssl
cd
openssl genrsa -out ca.key 2048
openssl req -new -key ca.key -out ca.csr <<EOT
GB
London
London
IBM
Cloud
webservice.lgnet.co.uk
.
.
.
EOT
openssl x509 -req -days 365 -in ca.csr -signkey ca.key -out ca.crt
cp ca.crt /etc/pki/tls/certs
cp ca.key /etc/pki/tls/private/ca.key
cp ca.csr /etc/pki/tls/private/ca.csr
sed -i "s/localhost.crt/ca.crt/g" /etc/httpd/conf.d/ssl.conf
sed -i "s/localhost.key/ca.key/g" /etc/httpd/conf.d/ssl.conf
service httpd restart

echo "********************************************************************************" 
echo "*                                   Quick Cleanup                              *" 
echo "********************************************************************************" 

cd
rm -rf ca*

exit 0

# ----------------------------------------------------------------------------------------
#
#                                    SCRIPT FINISHES
#
# ----------------------------------------------------------------------------------------
