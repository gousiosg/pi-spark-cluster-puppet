# (c) 2017 - onwards Georgios Gousios <gousiosg@gmail.com>
#
# Various commands to setup a Raspberry Pi cluster.
#

# NOT MEANT TO BE RUN AS A SCRIPT

# On the Mac

###
## On the cluster master node
###
# Create the master node, install and run puppet
ssh pi@192.168.1.23
sudo apt-get update && sudo apt-get upgrade -y

## Change hostname
echo "master.spark"|sudo tee /etc/hostname

## Install and config puppet
sudo apt-get install puppet git curl screen software-properties-common build-essential pssh
sudo adduser gousiosg
sudo usermod -a -G sudo gousiosg
scp -r gousiosg@dutihr.st.ewi.tudelft.nl:~/.ssh .
#scp -r bdp1.ewi.tudelft.nl:~/cluster .

sudo gem install librarian-puppet
cd cluster
librarian-puppet install
sudo puppet apply --modulepath=modules nodes.pp

# Puppet config according to
# https://www.digitalocean.com/community/tutorials/how-to-install-puppet-to-manage-your-server-infrastructure
# Unfortunately too manual

## Puppet master configuration
## Remove default certificates
sudo apt-get install puppetmaster-passenger git
sudo service apache2 stop
sudo rm -rf /var/lib/puppet/ssl
sudo ln -s /home/gousiosg/cluster/files /etc/puppet/files
sudo ln -s /home/gousiosg/cluster/nodes.pp /etc/puppet/manifests/site.pp
sudo ln -s /home/gousiosg/cluster/modules /etc/puppet/modules

## edit file /etc/puppet/puppet.conf
vi /etc/puppet/puppet.conf

## Restart puppet
sudo service puppetmaster restart

# On each puppet node
## 1. set host name to slaveX.spark
passwd pi
echo "slave1.spark"|sudo tee /etc/hostname
sudo reboot

## 2. Install and configure puppet
sudo apt-get update
sudo apt-get install puppet
sudo bash
cat > /etc/puppet/puppet.conf << EOF
[main]
logdir=/var/log/puppet
vardir=/var/lib/puppet
ssldir=/var/lib/puppet/ssl
rundir=/var/run/puppet
factpath=$vardir/lib/facter
prerun_command=/etc/puppet/etckeeper-commit-pre
postrun_command=/etc/puppet/etckeeper-commit-post
server=master.spark

[master]
# These are needed when the puppetmaster is run by passenger
# and can safely be removed if webrick is used.
ssl_client_header = SSL_CLIENT_S_DN
ssl_client_verify_header = SSL_CLIENT_VERIFY
EOF

sudo service puppet restart
sudo puppet agent --enable
sudo puppet agent --test

## 3. On the puppet master, sign the client certificates
sudo puppet cert sign --all
