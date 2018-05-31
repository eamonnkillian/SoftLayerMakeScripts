#!/bin/bash
#
# Created:      10-June-2016
# Author:       EJK
# Description:
#
# A short post installation utility script to set up  a Nagios 'Monitoring Server' on a
# private network within SoftLayer. This file can be executed standalone or implemented as
# part of a post installation script. The script itself does the following:
#
# - carries out a yum update;
# - installs httpd, php, gd, gd-devel, perl, and perl-devel;
# - installs Python 3.3.3 (note: this is optional)
# - adds the Python setup tools (note: this is optional)
# - adds a 'sysadm' user;
# - adds the 'sysadm' user to sudoers file;
# - add the 'sysadm' ssh keys;
# - restarts ssh daemon;
# - sets the timezone correctly;
# - adds the Nagios service users & groups ;
# - gets the Nagios service packages;
# - installs Nagios; &
# - adds Nagios web GUI.
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

LOGFILE="logs/make-nagiosserver.log"
sysadmuid="968"
sysadmuser="sysadm"
nagiosfiles="http://10.164.91.13/files/NAGIOS/"
pythonfiles="http://10.164.91.13/files/PYTHON/"
package="epel-release-6-8.noarch.rpm"
pythonthree="Python-3.3.3.tar.xz"
setupfile="setuptools-1.4.2.tar.gz"
pipfiles=("get-pip.py" "pip-8.1.2-py2.py3-none-any.whl" "wheel-0.29.0-py2.py3-none-any.whl")
nagiospackage="nagios-4.1.1.tar.gz"
nagioswebgui="nagios-plugins-2.1.1.tar.gz"

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
# Lets quickly install some needed packages for Python 3.3.3
#

echo "********************************************************************************"
echo "*                  executing Yum install of required packages                  *"
echo "********************************************************************************"

yum -y groupinstall 'Development tools'
yum -y install zlib-dev openssl-devel sqlite-devel bzip2-devel
yum -y install httpd php gd gd-devel perl perl-devel unzip 
yum -y install gcc glibc glibc-common make net-snmp

#
# Now lets download Python 3.3.3 from our internal mirror
#

echo "********************************************************************************"
echo "*                              executing Python install                        *"
echo "********************************************************************************"

wget $pythonfiles$pythonthree
xz -d $pythonthree
tar -xvf Python-3.3.3.tar
cd Python-3.3.3
./configure
make
make altinstall

#
# Now we need root to know about Python 3.3.3
#

echo "alias python=/usr/local/bin/python3.3" >> ~root/.bashrc
echo 'export PATH="/usr/local/bin:$PATH"' >> ~root/.bashrc
source ~root/.bashrc

#
# Now to install the Python setup tools
#

echo "********************************************************************************"
echo "*                            executing Python Setuptools                       *"
echo "********************************************************************************"

cd
wget $pythonfiles$setupfile
tar -xvf $setupfile
cd setuptools-1.4.2
/usr/local/bin/python3.3 setup.py install
cd

#
# To install Pip without Internet access we will need the pip files
#

echo "********************************************************************************" 
echo "*                              executing Pip install                           *" 
echo "********************************************************************************" 

for i in "${pipfiles[@]}"
   do
      wget $pythonfiles$i
   done

/usr/local/bin/python3.3 get-pip.py --no-index --find-links=/root

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

#
# Add the Nagios user and group
#

echo "********************************************************************************"
echo "*                   adding Nagios service users & groups                       *"
echo "********************************************************************************"

id -u nagios > /dev/null
if [ $? == 1 ]; then
   useradd nagios -c "Nagios User" -m
fi

groupadd nagcmd
usermod -a -G nagcmd nagios
usermod -a -G nagcmd apache

echo "********************************************************************************"
echo "*                      getting the Nagios service packages                     *"
echo "********************************************************************************"

cd
wget $nagiosfiles$nagiospackage
wget $nagiosfiles$nagioswebgui

echo "********************************************************************************"
echo "*                                installing Nagios                             *"
echo "********************************************************************************"
tar zxvf nagios-4.1.1.tar.gz 
cd nagios-4.1.1
./configure --with-command-group=nagcmd
make all
make install
make install-init
make install-config
make install-commandmode
sed -i "s/nagios@localhost/root@localhost.com/g" /usr/local/nagios/etc/objects/contacts.cfg 
make install-webconf
htpasswd -cb /usr/local/nagios/etc/htpasswd.users nagiosadmin passw0rd
service httpd restart
systemctl mask firewalld

echo "********************************************************************************"
echo "*                              adding Nagios web GUI                           *"
echo "********************************************************************************"

cd
tar zxvf nagios-plugins-2.1.1.tar.gz 
cd nagios-plugins-2.1.1
./configure --with-nagios-user=nagios --with-nagios-group=nagios
make
make install
chkconfig --add nagios
chkconfig nagios on
chkconfig --add httpd
chkconfig httpd on

chkconfig nagios on
service nagios restart

exit 0

# ----------------------------------------------------------------------------------------
#
#                                    SCRIPT FINISHES
#
# ----------------------------------------------------------------------------------------
