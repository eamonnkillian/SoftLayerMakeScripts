#!/bin/bash
#
# Created:      05-June-2016
# Author:       EJK
# Description:
#
# A short post installation utility script to set up  an Ansible 'Controlling Machine' a 
# private network within SoftLayer. This file can be executed standalone or implemented as 
# part of a post installation script. The script itself does the following:
#
# - carries out a yum update;
# - installs the developer group tools
# - installs openssl, sqllite and bzip
# - installs Python 3.3.3
# - adds the Python setup tools
# - adds Python pip
# - installs the SoftLayer CLI tool
# - adds a 'sysadm' user;
# - adds the 'sysadm' user to sudoers file;
# - add the 'sysadm' ssh keys;
# - restarts ssh daemon;
# - sets the timezone correctly;
# - installs the EPEL repository;
# - installs Ansible.
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

LOGFILE="logs/makeansiblemaster.log"
sysadmuid="968"
sysadmuser="sysadm"
repofiles="http://10.164.91.13/files/EPELREPOSITORIES/"
pythonfiles="http://10.164.91.13/files/PYTHON/"
package="epel-release-6-8.noarch.rpm"
pythonthree="Python-3.3.3.tar.xz"
setupfile="setuptools-1.4.2.tar.gz"
pipfiles=("get-pip.py" "pip-8.1.2-py2.py3-none-any.whl" "wheel-0.29.0-py2.py3-none-any.whl")

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
echo "*                  executing Yum Groupinstall 'development tools'              *" 
echo "********************************************************************************" 

yum groupinstall -y 'development tools'
yum install -y zlib-dev openssl-devel sqlite-devel bzip2-devel

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

/usr/local/bin/python3.3  get-pip.py --no-index --find-links=/root

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
# We have to install the EPEL repository first from our internal web server
#

echo "********************************************************************************" 
echo "*                              adding EPEL repository                          *" 
echo "********************************************************************************" 

wget http://10.164.91.13/files/EPELREPOSITORIES/epel-release-6-8.noarch.rpm
rpm -ivh epel-release-6-8.noarch.rpm

#
# Now we can install Ansible 
#

echo "********************************************************************************"
echo "*                               installing Ansible                             *" 
echo "********************************************************************************" 

yum -y install ansible
ansible --version

#
# And to finalize we can instal the SoftLayer CLI 
#

echo "********************************************************************************" 
echo "*                              executing SLCLI install                         *" 
echo "********************************************************************************" 

pip install softlayer

#
# Lets clean up /root as a final step 
#

echo "********************************************************************************" 
echo "*                                executing Clean Up                            *" 
echo "********************************************************************************" 

cd
rm -f epel*
rm -f pip*
rm -f wheel*
rm -f get*
rm -rf Python*
rm -rf setup*

exit 0

# ----------------------------------------------------------------------------------------
#
#                                    SCRIPT FINISHES
#
# ----------------------------------------------------------------------------------------
