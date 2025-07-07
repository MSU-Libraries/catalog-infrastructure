#!/bin/bash

# shellcheck disable=SC2154

### Setup root user which is used by CI to run the configure-playbook
sudo -Hsu root -- <<-ROOT
    install -d -m 0700 /root/.ssh
    echo "${root_public_key}" >> /root/.ssh/authorized_keys
    chmod 0600 /root/.ssh/authorized_keys
ROOT


### Create ansible user if a key is provided,
### so that the ubuntu-setup-playbook can be run
if [[ -n ${ansible_public_key} ]]; then
    sudo useradd -m -u 4444 -s /bin/bash ansible
    echo "ansible ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
    sudo -Hsu ansible -- <<-ANSIBLE
          cd
          umask 077
          mkdir .ssh
          echo "${ansible_public_key}" >> .ssh/authorized_keys
    ANSIBLE
fi

### Install packages required for mail configuration 
sudo -Hs -- <<-POSTSETUP
	debconf-set-selections <<< "postfix postfix/mailname string ${mail_name}"
	debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
	DEBIAN_FRONTEND=noninteractive \
	apt update && \
	apt install mailutils postfix libsasl2-modules -y
	sleep 5
	umask 077
	echo "[${smtp_host}]:587 ${smtp_user}:${smtp_password}" > /etc/postfix/sasl_passwd
	postmap hash:/etc/postfix/sasl_passwd
	postconf -e "relayhost = [${smtp_host}]:587" \
	"smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt" \
	"myhostname = ${mail_name}" \
	"append_dot_mydomain = yes" \
	"smtp_sasl_auth_enable = yes" \
	"smtp_sasl_security_options = noanonymous" \
	"smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd" \
	"smtp_use_tls = yes" \
	"smtp_tls_security_level = encrypt" \
	"smtp_tls_note_starttls_offer = yes" \
	"inet_interfaces = loopback-only"
	systemctl restart postfix
POSTSETUP
