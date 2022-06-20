#!/bin/bash

### Create ansible user
sudo useradd -m -u 4444 -s /bin/bash ansible
sudo echo "ansible ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
sudo -Hsu ansible -- <<-ANSIBLE
	cd
	umask 077
	mkdir .ssh
	echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIChaBRQuzsZVT4S2/yYiahfam7IDAVx42YJOoOpc2fYy ansible@ansible.lib.msu.edu" > .ssh/authorized_keys
ANSIBLE
sleep 10
