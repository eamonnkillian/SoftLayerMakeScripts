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
# - carries out a yum update;
# - yum installs the EPEL release;
# - yum installs fail2ban;
# - configures fail2ban;
# - adds a 'sysadm' user;
# - adds the 'sysadm' user to sudoers file;
# - adds the 'sysadm' ssh keys;
# - restarts ssh daemon;
# - sets the timezone correctly;
# - installs the apache server;
# - installs Python 3.5.2 pre-requisites;
# - installs Python 3.5.2 as alternate Python;
# - installs Python setuptools;
# - installs Python pip;
# - pip install Django; 
# - installs MySQL;
# - installs Apache; 
# - installs Apache to Python Link through mod-wsgi;
# - installs Python to MySQL link;
# - configures MySQL;
# - starts MySQL; and
# - starts Apache. 
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

LOGFILE="logs/makedjango.log"
sysadmuid="968"
sysadmuser="sysadm"
pythonfiles="http://10.164.91.13/files/PYTHON/"
pythonthree="Python-3.5.2.tar.xz"
pythontarfile="Python-3.5.2.tar"
pythondirectory="Python-3.5.2"
setupfile="setuptools-1.4.2.tar.gz"
pipfiles=("get-pip.py" "pip-8.1.2-py2.py3-none-any.whl" "wheel-0.29.0-py2.py3-none-any.whl")
myprivateip=`ifconfig eth0 2>/dev/null | awk '/inet addr:/ {print $2}'|sed 's/addr://'`
myprivatenetwork=${myprivateip%.*}
NETCONFIG="/etc/sysconfig/network-scripts/ifcfg-eth0"

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

#
# Lets quickly update the yum repositories
#

echo "********************************************************************************" 
echo "*                            executing IPTables set up                         *" 
echo "********************************************************************************" 

#
# Lets quickly do our IP tables
#
# There are issues with getting iptables to work when a private only network is in 
# place. The error is usually "Error: Cannot retrieve metalink for repository: epel. 
# Please verify its path and try again". In the end the fix related to adding a line
# in /etc/sysconfig/network-scripts/ifcfg-eth0 for the default gateway. This is 
# generally the '.1' machine on the network that the machine is on so we can parse 
# out the network element and add this to the file before running the two next sections
# of script. This of course then relies on your Vyatta on the account being set up to
# allow NAT masquerade traversal to external addresses outside of SoftLayer so that 
# external package sites are reachable.
# 

echo "GATEWAY=$myprivatenetwork.1" >> $NETCONFIG
service network restart

#
# Now iptables allowing DNS, YUM, HTTP, HTTPS, SSH on the private network
#

iptables -F
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
echo "STEP 1: Total Lockdown Achieved"
iptables -A INPUT --in-interface lo -j ACCEPT
iptables -A OUTPUT --out-interface lo -j ACCEPT
echo "STEP 2: Loopback interface access enabled"
iptables -A INPUT --in-interface eth0 -p icmp --icmp-type echo-request -m iprange --src-range 10.0.0.0-10.255.255.255 -j ACCEPT
iptables -A OUTPUT --out-interface eth0 -p icmp --icmp-type echo-reply -j ACCEPT
echo "STEP 3: Private interface INBOUND PING enabled."
iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT
echo "STEP 4: Private interfaces OUTBOUND PING enabled."
iptables -A INPUT --in-interface eth0 -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT
echo "STEP 5: Private network SSH access enabled"
iptables -A OUTPUT -p udp --out-interface eth0 --dport 53 -j ACCEPT
iptables -A INPUT -p udp --in-interface eth0 --sport 53 -j ACCEPT
echo "STEP 6: Private DNS access enabled"
iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 20 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -p tcp -m tcp -m state --state NEW --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp -m tcp -m state --state NEW --dport 443 -j ACCEPT
echo "STEP 7: Private Yum access enabled"
service iptables save
service iptables restart
echo "IPTables set up complete"

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
# Lets quickly install some needed packages for Python 3.5.2
#

echo "********************************************************************************"
echo "*                  executing Yum install of required packages                  *"
echo "********************************************************************************"

yum -y groupinstall 'Development tools'
yum -y install zlib-dev openssl-devel sqlite-devel bzip2-devel
yum -y install httpd php gd gd-devel perl perl-devel unzip 
yum -y install gcc glibc glibc-common make net-snmp

#
# Now lets download Python 3.5.2 from our internal mirror
#

echo "********************************************************************************"
echo "*                              executing Python install                        *"
echo "********************************************************************************"

wget $pythonfiles$pythonthree
xz -d $pythonthree
tar -xvf $pythontarfile
cd $pythondirectory
./configure
make
make altinstall

#
# Now we need root to know about Python 3.5.2
#

echo "alias python=/usr/local/bin/python3.5" >> ~root/.bashrc
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
/usr/local/bin/python3.5 setup.py install
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

/usr/local/bin/python3.5  get-pip.py --no-index --find-links=/root

#
# To install MySQL
#

echo "********************************************************************************"
echo "*                            executing MySQL install                           *"
echo "********************************************************************************"

yum -y install mysql-server
chkconfig --levels 235 mysqld on
service mysqld start

/usr/bin/mysql_secure_installation <<_EOT

Y
password
password
Y
Y
Y
Y
_EOT


#
# To install Apache
#

echo "********************************************************************************"
echo "*                              executing Apache install                        *"
echo "********************************************************************************"

yum -y install httpd
chkconfig --levels 235 httpd on
service httpd start

#
# To install Apache mod-wsgi module
#

echo "********************************************************************************"
echo "*                           executing mon_wsgi install                         *"
echo "********************************************************************************"

yum -y install mod_wsgi

#
# Finally we can install Django
#

echo "********************************************************************************"
echo "*                            executing Django install                          *"
echo "********************************************************************************"

pip install django

exit 0

# ----------------------------------------------------------------------------------------
#
#                                    SCRIPT FINISHES
#
# ----------------------------------------------------------------------------------------















