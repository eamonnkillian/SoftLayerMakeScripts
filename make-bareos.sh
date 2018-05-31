#!/bin/bash
#
# Created:      10-June-2016
# Author:       EJK
# Description:
#
# A short post installation utility script to set up a Bareos 'Backup Server' on a
# private network within SoftLayer. This file can be executed standalone or implemented as
# part of a post installation script. The script itself does the following:
#
# - carries out a yum update;
# - adds a 'sysadm' user;
# - adds the 'sysadm' user to sudoers file;
# - add the 'sysadm' ssh keys;
# - restarts ssh daemon;
# - sets the timezone correctly;
# -  ;
# -  ;
# -  ; &
# - adds Bareos web GUI.
#
# Dependencies:
# 1) A reachable internal/private network only web server with the Chef Master packages;
# 2) A SoftLayer account;
# 3) Assumes CentOS 6 operating system.
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

LOGFILE="logs/makebareosserver.log"
sysadmuid="968"
sysadmuser="sysadm"
DISKDEV="/dev/xvdc"
MOUNTPOINT="/var/lib/bareos/storage"
DIST=CentOS_6
DATABASE=mysql
URL=http://download.bareos.org/bareos/release/latest/$DIST
BAREOSCONFDIR="/etc/bareos/bareos-dir.d/"
WEBUICNF="webui-consoles.conf"

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

echo "********************************************************************************"
echo "*                              setting the timezone                            *"
echo "********************************************************************************"

rm -rf /etc/localtime
ln -s /usr/share/zoneinfo/Europe/London /etc/localtime


echo "********************************************************************************"
echo "*                          setting up the second SAN drive                     *"
echo "********************************************************************************"

fdisk $DISKDEV <<_END
n
p
1
1

p
w
_END
mkfs.ext4 $DISKDEV

#
# Adding the EPEL repositories
#

echo "********************************************************************************"
echo "*                          adding the EPEL repositories                        *"
echo "********************************************************************************"

yum -y install epel-release

#
# Adding MySQL and PHP if you did not choose a LAMP server on creation
#

echo "********************************************************************************"
echo "*                          adding Apache, MySQL and PHP                        *"
echo "********************************************************************************"

yum -y install httpd mysql mysql-server php php-mysql

service httpd start
chkconfig httpd on
service mysqld start
chkconfig mysqld on

mysql_secure_installation <<EOT

Y
passw0rd
passw0rd
Y

Y
Y
EOT

#
# Adding Bareos
#

echo "********************************************************************************"
echo "*                                 adding Bareos                                *"
echo "********************************************************************************"

wget -O /etc/yum.repos.d/bareos.repo $URL/bareos.repo
yum -y install bareos bareos-database-$DATABASE

echo "********************************************************************************"
echo "*                               setting up .my.cnf                             *"
echo "********************************************************************************"

echo "[client]" > .my.cnf
echo "host=localhost" >> .my.cnf
echo "user=root" >> .my.cnf
echo "password=passw0rd" >> .my.cnf

echo "********************************************************************************"
echo "*                      adding our large disk for our backups                   *"
echo "********************************************************************************"

echo "$DISKDEV $MOUNTPOINT     ext4    defaults        1 2" >> /etc/fstab
mount -a
chown bareos:bareos $MOUNTPOINT
chmod 0775 $MOUNTPOINT

echo "********************************************************************************"
echo "*                            configuring bareos services                       *"
echo "********************************************************************************"

/usr/lib/bareos/scripts/create_bareos_database
/usr/lib/bareos/scripts/make_bareos_tables
/usr/lib/bareos/scripts/grant_bareos_privileges

service bareos-dir start
service bareos-sd start
service bareos-fd start

echo "********************************************************************************"
echo "*                               adding bareos web gui                          *"
echo "********************************************************************************"

yum -y install bareos-webui
echo "@/etc/bareos/bareos-dir.d/webui-consoles.conf" >> /etc/bareos/bareos-dir.conf
echo "@/etc/bareos/bareos-dir.d/webui-profiles.conf" >> /etc/bareos/bareos-dir.conf

sed -i "s/user1/sysadm/g" $BAREOSCONFDIR$WEBUICNF
sed -i "s/CHANGEME/passw0rd/g" $BAREOSCONFDIR$WEBUICNF

service bareos-dir restart
service bareos-sd restart
service bareos-fd restart
service httpd restart

exit 0

# ----------------------------------------------------------------------------------------
#
#                                    SCRIPT FINISHES
#
# ----------------------------------------------------------------------------------------
