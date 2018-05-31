#!/bin/bash
#
# Created:      10-June-2016
# Author:       EJK
# Description:
#
# A short post installation utility script to set up an Oracle 11gR2 database server on a
# private network within SoftLayer. This file can be executed standalone or implemented
# part of a post installation script. The script itself does the following:
#
# - creates a logfile so we can debug;
# - carries out a yum update;
# - adds a 'sysadm' user;
# - adds the 'sysadm' user to sudoers file;
# - adds the 'sysadm' ssh keys;
# - restarts ssh daemon;
# - sets the timezone correctly;
# - runs fdisk to format the additional disk;
# - makes an 'ext4' filesystem on the additional disk;
# - increases the swap space from the default setting;
# - installs the unixODBC packages;
# - group installs the X window system;
# - group installs the development tools;
# - group installs the desktop;
# - installs the RPMs required by Oracle;
# - manually installs the compat-stdc++ package (issues were occurring so this makes sure!)
# - changes the init level to 5 so GUI available;
# - carries out the Kernel configuration;
# - adds the login and file limits;
# - adds the users and groups required;
# - gets the Oracle packages; and 
# - installs Oracle.
#
# Notes: 
# 1) This install can be achieved silently/hands free but can also be edited so that the
# final steps of the Oracle install can be done using the Oracle Universal Installer. If 
# you decide to run the installer silently then please make sure you edit the response 
# file to reflect your requirements.
# 2) This script assumes CentOS but can be modified for RHEL or other Linux.
# 3) Make sure you order your machine with the two SAN disks or two local disks. If 
# ordered as two locals you may need to alter the section dealing with fdisk and making 
# the filesystem to reflect your install. In these cases it may be better/more efficient 
# to copy this script to the machine after vanilla OS install and run manually.
#
# Dependencies:
# 1) A reachable internal/private network with a web service & packages files;
# 2) A SoftLayer account;
# 3) Assumes CentOS 6 operating system;
# 4) Ordered a machine with at least 2 cores, 8GB memory and TWO san disks 25GB & 25GB.
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

LOGFILE="logs/makeoracleserver.log"
sysadmuid="968"
sysadmuser="sysadm"
DISKDEV="/dev/xvdc"
MOUNTPOINT="/oracle"
ORACLEFILES="http://10.164.91.13/files/ORACLE/"
SYSCTLFILE="sysctl.conf"
LOGINFILE="login"
LIMITSFILE="limits.conf"
BASHPROFILE="bash_profile"
ORACLEZIP1="linux.x64_11gR2_database_1of2.zip"
ORACLEZIP2="linux.x64_11gR2_database_2of2.zip"
COMPATRPM="compat-libstdc++-33-3.2.3-47.3.x86_64.rpm"
RESPONSEFILE="oracle-response.rsp"
MYHOSTNAME=`hostname`

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
   echo "sysadm    ALL=(ALL)       NOPASSWD:ALL" >> /etc/sudoers
else
   userdel -r $sysadmuser
   useradd $sysadmuser -u $sysadmuid -c "Standard Systems Administration User" -m
   echo "sysadm    ALL=(ALL)       NOPASSWD:ALL" >> /etc/sudoers
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

echo "********************************************************************************"
echo "*                         mounting the second filesystem                       *"
echo "********************************************************************************"

if [ ! -d "$MOUNTPOINT" ]; then
   mkdir $MOUNTPOINT
fi

mount $DISKDEV $MOUNTPOINT
echo "$DISKDEV	$MOUNTPOINT	ext4	defaults	1 2" >> /etc/fstab

#
# EJK - By default RHEL or CentOS VMs instanced on SoftLayer won't have twice the 
# memory swap space which Oracle needs.
#

echo "********************************************************************************"
echo "*                            increasing the swap space                         *"
echo "********************************************************************************"

declare -i MEMINFO
declare -i SWAPINFO
MEMINFO=`cat /proc/meminfo | head -1 | awk '{print $2}'`
SWAPINFO=`cat /proc/meminfo | grep SwapTotal | awk '{print $2}'`
MEMTEST=$(($MEMINFO*2))
if [ $SWAPINFO -lt $MEMTEST ]; then
   dd if=/dev/zero of=/swapfile bs=1024 count=$MEMTEST
   mkswap /swapfile
   swapon /swapfile
   cat /proc/meminfo
   echo "/swapfile	swap	swap	defaults	0 0" >> /etc/fstab
fi

echo "********************************************************************************"
echo "*                         adding the ODBC unix dev package                     *"
echo "********************************************************************************"

yum -y install unixODBC
yum -y install unixODBC-devel

echo "********************************************************************************"
echo "*                    adding the other required unix dev packages               *"
echo "********************************************************************************"

yum -y groupinstall "X Window System"
yum -y groupinstall "Development tools"
yum -y groupinstall "Desktop" "Desktop Platform" "Fonts"
yum -y install elfutils-devel
yum -y install elfutils-lib
yum -y install gcc
yum -y install gcc-c++
yum -y install glibc
yum -y install glibc-devel
yum -y install libaio-devel
yum -y install libaio
yum -y install libgcc
yum -y install libstdc++
yum -y install libtool-ltdl
yum -y install nss-softokn-freebl
yum -y install readline
yum -y install ncurses-libs
yum -y install libcap
yum -y install libattr
yum -y install compat-libcap1
yum -y install compat-libstdc++
yum -y install pdksh
yum -y install xterm
yum -y install bzip

#
# EJK - Some issues have been experienced during Oracle install with this rpm
# so just in case the rpm is held on the web service server in the Oracle directory.
# We will manually install just in case there was an error for CentOS.
#

wget $ORACLEFILES$COMPATRPM
rpm -Uvh $COMPATRPM


sed -i "s/id:3/id:5/g" /etc/inittab
init 5

echo "********************************************************************************"
echo "*                         doing the Kernel configuration                       *"
echo "********************************************************************************"

wget $ORACLEFILES$SYSCTLFILE
mv -f $SYSCTLFILE /etc/$SYSCTLFILE
chmod 0644 /etc/$SYSCTLFILE
sysctl -p

echo "********************************************************************************"
echo "*                         doing the login and file limits                      *"
echo "********************************************************************************"

wget $ORACLEFILES$LOGINFILE
mv -f $LOGINFILE /etc/pam.d/$LOGINFILE
wget $ORACLEFILES$LIMITSFILE
mv -f $LIMITSFILE /etc/security/$LIMITSFILE

echo "********************************************************************************"
echo "*                             adding groups and users                          *"
echo "********************************************************************************"

getent group dba
if [ $? != 0 ]; then
   groupadd dba
fi
getent group oinstall
if [ $? != 0 ]; then
   groupadd oinstall 
fi
getent passwd oracle
if [ $? != 0 ]; then
   useradd -g oinstall -G dba oracle
   passwd oracle <<EOT
oracle
oracle
EOT
fi 

echo "********************************************************************************"
echo "*                          adding oracle app directory                         *"
echo "********************************************************************************"

if [ ! -d "/oracle/app" ]; then
   mkdir /oracle/app
fi
chown -R oracle:dba /oracle/app
wget $ORACLEFILES$BASHPROFILE
mv -f $BASHPROFILE ~oracle/.$BASHPROFILE
chown oracle:oinstall ~oracle/.$BASHPROFILE

echo "********************************************************************************"
echo "*                               installing  oracle                             *"
echo "********************************************************************************"

mkdir /oracle/tmp
chown oracle:oinstall /oracle/tmp
cd /oracle/tmp
wget $ORACLEFILES$ORACLEZIP1
wget $ORACLEFILES$ORACLEZIP2
unzip $ORACLEZIP1
unzip $ORACLEZIP2
chown oracle:oinstall *
cd /oracle/tmp/database
wget $ORACLEFILES$RESPONSEFILE
chown oracle:oinstall oracle-response.rsp
sed -i "s/XXXXXXXX/$MYHOSTNAME/g" oracle-response.rsp
su - oracle -c "/oracle/tmp/database/runInstaller -ignoreSysPrereqs -ignorePrereq -silent -nowelcome -nowait -responseFile /oracle/tmp/database/oracle-response.rsp"

#
# EJK - We must now wait for this install process to finish - Using 7 minutes
#

echo "********************************************************************************"
echo "*                           finishing the oracle install                       *"
echo "********************************************************************************"

sleep 420
/oracle/app/oraInventory/orainstRoot.sh 
/oracle/app/oracle/product/11.2.0/dbhome_1/root.sh

echo "********************************************************************************"
echo "*                                                                              *"
echo "*  NOTE:                                                                       *"
echo "*  Now the installation is complete please do not forget to log in as Oracle   *"
echo "*  and to add a 'netlistener' and to start using 'dbca' to create databases.   *"
echo "*                                                                              *"
echo "********************************************************************************"

echo "********************************************************************************"
echo "*                                   Quick Cleanup                              *"
echo "********************************************************************************"

cd

exit 0

# ----------------------------------------------------------------------------------------
#
#                                    SCRIPT FINISHES
#
# ----------------------------------------------------------------------------------------

