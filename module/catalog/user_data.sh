#!/bin/bash

### Create ansible user
sudo useradd -m -u 4444 -s /bin/bash ansible
sudo echo "ansible ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
sudo -Hsu ansible -- <<-ANSIBLE
	cd
	umask 077
	mkdir .ssh
	echo "***REMOVED***" > .ssh/authorized_keys
ANSIBLE
sleep 10
