#!/bin/bash
#
# Created:	03-May-2016
# Author:	EJK
# Description:
#
# A short post installation utility script to set up the bare minimum new machine
# requirements for both auto-scaled and portal instanced machines on the customers 
# SoftLayer account. In detail this script:
#
# - Adds the required hostnames to /etc/hosts
# - Copies over (using wget) the necessary init & install scripts
# - RPM installs the 'chef-client' software
# - Initiates the 'first convergence' of Chef
# - Implements the 'chef-client' as a daemon process to survive reboots
#
# Dependencies:
# 1) A Chef Master server extant and reachable;
# 2) An image on the account with the requisite RPMS already installed.
#
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
# CRITCIALLY IMPORTANT!!!!
# It is critically important to understand the role of the "first-boot.json" file in the 
# chef-config line below. This file should be copied multiple times to link to the creation
# of multiple "roles" within your own Chef environment. 
#

cheffiles="http://10.164.91.13/files/CHEFFILES/"
packages="http://10.164.91.13/files/PACKAGEFILES/"
chefclient="chef-12.9.41-1.el5.x86_64.rpm"
chefconfig=("client.rb" "first-boot.json" "validation.pem" "llontchm001poc.lgnet.co.uk.crt")
initscript="http://10.164.91.13/files/INITSCRIPT/chef-init"
daemonscript="chef-init"

#
# Lets quickly update the yum repositories
#

yum -y update

#
# Add your Chef Server and workstation to the hosts file here!!!
#

echo "10.164.91.9 llontchm001poc.lgnet.co.uk llontchm001poc" >> /etc/hosts
echo "10.164.91.10 llontchw001poc.lgnet.co.uk llontchw001poc" >> /etc/hosts

#
# We finally need to automatically install the Chef Client on the new machine
# and this involves copying over all of the necessary Chef bootstrap files and
# the Chef package from our CHEFFILES repository. This package will be platform
# specific dependant on what type of Chef Client we are building. This bootstrap
# script is the RedHat5.5 script!
#

wget $packages$chefclient
rpm -Uvh $chefclient

mkdir /etc/chef
chmod 755 /etc/chef
mkdir /etc/chef/trusted_certs
chmod 755 /etc/chef/trusted_certs

for i in "${chefconfig[@]}"
do
   fetchstring=$cheffiles$i
   wget $fetchstring --no-check-certificate
   if [ $i == "llontchm001poc.lgnet.co.uk.crt" ]; then
      mv -f $i /etc/chef/trusted_certs/
   elif [ $i == "validation.pem" ]; then
      mv -f $i /etc/chef
      chmod 600 /etc/chef/$i
   else
      mv -f $i /etc/chef/
   fi
done

#
# CRITICALLY IMPORTANT!!!
# If you have kept "first-boot.json" then this line will work. If you have created a new 
# Chef client "role" and boot file then replace here!!!
#

chef-client -j /etc/chef/first-boot.json

#
# Finally get the Chef Client initization script
#

wget $initscript
chmod 0755 $daemonscript
mv -f $daemonscript /etc/init.d/
chkconfig --add chef-init

#
# Reboot to finalize
#

reboot

# ----------------------------------------------------------------------------------------
#
#                                    SCRIPT FINISHES
#
# ----------------------------------------------------------------------------------------
