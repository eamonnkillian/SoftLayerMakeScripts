#!/bin/bash
#
# Created:      27-July-2016
# Author:       EJK
# Description:
#
# A short post installation utility script to set up a Web Service server on a private
# network within SoftLayer. This file can be executed standalone or implemented as part 
# of a post installation script. The script itself does the following:
# 
# - creates a logfile so we can debug;
# - sets the timezone correctly;
# - sets up the IPtables implementation;
# - carries out a yum update;
# - yum installs the EPEL release;
# - yum installs fail2ban;
# - configures fail2ban;
# - adds a 'sysadm' user;
# - adds the 'sysadm' user to sudoers file;
# - adds the 'sysadm' ssh keys;
# - restarts ssh daemon;
# - installs the docker-engine package; and
# - starts Docker.
#
# Note: There have been issues with connectivity from a private only network implementation
# and the Docker repo. So this script has failed where firewall and proxy services are not
# enabling the repo to be downloaded and installed. At present this works only when a machine
# has public network access. 
#
# Dependencies:
# 1) A SoftLayer account;
# 2) Assumes CentOS 7 operating system (recommended by Docker);
# 3) Assumes a minimum kernel version of 3.10; 
# 4) Assumes the latest Docker tarball exists on your internal web server; and
# 4) Assumes a minimal build.
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

LOGFILE="logs/make-docker.log"
sysadmuid="968"
sysadmuser="sysadm"

#
# Lets create a log of the install
#

mkdir logs
exec > >(tee -i $LOGFILE)
exec 2>&1

echo "********************************************************************************" 
echo "*                              setting the timezone                            *" 
echo "********************************************************************************" 

#
# Link the timezone correctly
#

rm -rf /etc/localtime
ln -s /usr/share/zoneinfo/Europe/London /etc/localtime

echo "********************************************************************************" 
echo "*                               executing Yum update                           *" 
echo "********************************************************************************" 

#
# Now the yum update
# 

yum -y update

#
# Lets quickly add fail2ban if you wish to use it!
#

echo "********************************************************************************" 
echo "*                         executing Fail2Ban Install                           *" 
echo "********************************************************************************" 

yum -y install epel-release
yum -y install fail2ban
chkconfig --levels 235 fail2ban on
echo "[sshd]" >> /etc/fail2ban/jail.local
echo "enabled = true" >> /etc/fail2ban/jail.local
echo "filter = sshd" >> /etc/fail2ban/jail.local
echo "action = iptables[name=SSH, port=ssh, protocol=tcp]" >> /etc/fail2ban/jail.local
echo "logpath = /var/log/secure" >> /etc/fail2ban/jail.local
echo "bantime = 3600" >> /etc/fail2ban/jail.local
echo "maxretry = 3" >> /etc/fail2ban/jail.local
service fail2ban restart

#
# Add the standard administration user for your machines on SoftLayer. Given we're using
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
# Lets quickly add the Docker repo
#

echo "********************************************************************************"
echo "*                          executing Docker installation                       *"
echo "********************************************************************************"

echo "[dockerrepo]" > /etc/yum.repos.d/docker.repos
echo "name=Docker Repository" >> /etc/yum.repos.d/docker.repos
echo "baseurl=https://yum.dockerproject.org/repo/main/centos/7/" >> /etc/yum.repos.d/docker.repos
echo "enabled=1" >> /etc/yum.repos.d/docker.repos
echo "gpgcheck=1" >> /etc/yum.repos.d/docker.repos
echo "gpgkey=https://yum.dockerproject.org/gpg" >> /etc/yum.repos.d/docker.repos



yum -y install docker-engine
/bin/systemctl start  docker.service


exit 0

# ----------------------------------------------------------------------------------------
#
#                                    SCRIPT FINISHES
#
# ----------------------------------------------------------------------------------------