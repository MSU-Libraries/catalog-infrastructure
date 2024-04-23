FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Detroit

USER root

# Perform updates
RUN apt-get update && \
    apt-get install software-properties-common curl gnupg openssh-client git python3-netaddr python3-dnspython -y --no-install-recommends

# Setup Timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN add-apt-repository --yes --update ppa:ansible/ansible && \
    # Install Ansible
     apt-get install moreutils gettext-base ansible pip openssl -y --no-install-recommends && \
    # Installing specific version of resolvelib to fix:
    # https://bugs.gentoo.org/795933 (see also: https://github.com/ansible-collections/community.digitalocean/issues/132)
    pip install --no-cache-dir -Iv 'resolvelib<0.6.0' && \
    # Dependency of Ansible module community.crypto.openssl_privatekey
    pip install --no-cache-dir-v cryptography && \
    ansible-galaxy collection install community.general ansible.posix community.docker && \
    # Install Terraform
    curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - && \
    add-apt-repository --yes --update "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"  && \
     apt-get install terraform -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

CMD ["bash"]
