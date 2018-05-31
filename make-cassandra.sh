#!/bin/bash
#
# Created:      30-June-2016
# Author:       EJK
# Description:
#
# A short post installation utility script to set up a single node Cassandra cluster on a
# private network within SoftLayer. This file can be executed standalone or implemented as
# part of a post installation script. The script itself does the following:
#
# - carries out a yum update;
# - adds a 'sysadm' user;
# - adds the 'sysadm' user to sudoers file;
# - add the 'sysadm' ssh keys;
# - restarts ssh daemon;
# - sets the timezone correctly;
# - adds the Cassandra user;
# - downloads the Java JDK;
# - adds Java JDK to the machine;
# - add Java and Cassandra PATH properties;
# - downloads the Cassandra tarball;
# - extracts Cassandra; 
# - moves Cassandra to the Cassandra users home directory; &
# - edits the Cassandra YAML file to set the node name.
#
# Dependencies:
# 1) A reachable internal/private network only web server with the Chef Master packages;
# 2) A SoftLayer account;
# 3) Assumes CentOS 7 operating system.
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

LOGFILE="logs/makecassandraserver.log"
sysadmuid="968"
sysadmuser="sysadm"
cassuser="cassandra"
cassuid="551"
JAVAVERSION="jdk-8u92-linux-x64.rpm"
TARORRPM="tar"
CASSTARBALL="apache-cassandra-3.7-bin.tar.gz"

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
echo "*                             setting the timezone                             *"
echo "********************************************************************************"

rm -rf /etc/localtime
ln -s /usr/share/zoneinfo/Europe/London /etc/localtime

#
# Adding Java JDK 
#

echo "********************************************************************************"
echo "*                                adding Java JDK                               *"
echo "********************************************************************************"

//wget wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u92-b14/$JAVAVERSION
//rpm -ivh $JAVAVERSION
// or ... see below

yum -y install java

echo "********************************************************************************"
echo "*                        adding Java to roots bash_profile                     *"
echo "********************************************************************************"

echo 'export PATH="$PATH:/usr/java/latest/bin" >> ~root/.bash_profile'
echo "export PATH >> ~root/.bash_profile"
echo "set JAVA_HOME=/usr/java/latest >> ~root/.bash_profile"

echo "********************************************************************************"
echo "*                          setting up the Cassandra user                       *"
echo "********************************************************************************"

id -u $cassuser > /dev/null
if [ $? == 1 ]; then
   useradd $scassuser -u $cassuid -c "Cassandra User" -m
else
   userdel -r $cassuser
   useradd $cassuser -u $cassuid -c "Cassandra User" -m
fi

passwd $cassuser <<EOT
t5QMF;{/rP>aW/c6
t5QMF;{/rP>aW/c6
EOT

echo "********************************************************************************"
echo "*                      getting the Cassandra tarball or RPM                    *"
echo "********************************************************************************"

if [ $TARORRPM = "tar" ]; then
	wget http://apache.mirror.anlx.net/cassandra/3.7/$CASSTARBALL
	tar zxvf $CASSTARBALL
	rm -rf $CASSTARBALL
	rm -rf *.tar
	mv apache* ~$cassuser/cassandra
    chown -R cassandra:cassandra ~$cassuser/cassandra
fi 

echo "********************************************************************************"
echo "*               add the Path variables to Cassandra users bash_profile         *"
echo "********************************************************************************"

echo 'export PATH="$PATH:/usr/java/latest/bin" >> ~$cassuser/.bash_profile'
echo "export PATH >> ~root/.bash_profile"
echo "set JAVA_HOME=/usr/java/latest >> ~$cassuser/.bash_profile"

echo "********************************************************************************"
echo "*                                        done                                  *"
echo "********************************************************************************"

exit 0

# ----------------------------------------------------------------------------------------
#
#                                    SCRIPT FINISHES
#
# ----------------------------------------------------------------------------------------
