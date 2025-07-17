# Catalog Infrastructure
Public catalog infrastructure files using Terraform to build
two server clusters on AWS.

**Contents**
* [First Time Setup](#first-time-setup)
    * [AWS User Setup](#aws-user-setup)
    * [GitLab Setup](#gitlab-setup)
    * [Deploy User Setup](#deploy-user-setup)
    * [Terraform Setup](#terraform-setup)
    * [DNS Setup](#dns-setup)
* [How To Guides](#how-to-guides)
    * [Manually run terraform commands](#manually-run-terraform-commands)
    * [Increasing node root partition size](#increasing-node-root-partition-size)
    * [Force recreation of a node](#force-recreation-of-a-node)
    * [Mounting the Shared Storage](#mounting-the-shared-storage)
* [Troubleshooting](#troubleshooting)
    * [Traefik Let's Encrypt certificates not renewing automatically](#traefik-lets-encrypt-certificates-not-renewing-automatically)

## First time setup

### AWS User Setup
An AWS user is required and will need to have multiple access roles granted to it in IAM
to perform the tasks required in Terraform. Below outline the permissions required on the group
the AWS user is attached to:  

Policy: `AmazonEC2FullAccess`
[Custom Policy](user-policy.json)

If you are using the above IAM policy as a template for yourself, be sure to modify any IDs
or resource names as needed (some are specifically named `msul`).  

Save the AWS Key and Secret for this user to be set in the GitLab CI/CD variables.

### GitLab Setup
GitLab is not required for using this repository -- it simply helps call all of the steps in
the correct order with the right parameters. If you want to use this repository without
GitLab you can still references the `.gitlab-ci.yml` file to help understand what steps
you would need to manually run in order to spin up your cluster(s). Like how to use the
below variables that would be in the CI/CD settings.

The following CI/CD variables must also be created: (note that GitLab supports defining different values for the same variable for
each environment, so you can have a `DEPLOY_HOST_1,2,3` for devel and different values for prod (and different values of
the `MAIN_TF_FILE` for shared).

* `AWS_KEY`: The AWS Key for the user with the above user-policy
* `AWS_SECRET`: The AWS Secret for the user with the above user-policy
* `ROOT_PRIVATE_KEY`: This is the `base64` encoded private key, the public key is in the Terraform environment definititions
* `DEPLOY_HOST_1`: The first node in the cluster (i.e. catalog-1.aws.lib.msu.edu)
* `DEPLOY_HOST_2`: The second node in the cluster
* `DEPLOY_HOST_3`: The third node in the cluster
* `VARIABLES_YAML_FILE`:  Containing the completed contents of the  `configure-playbook/variables.yml.example`
  file leaving in `$` variable references like `REGISTRY_ACCESS_TOKEN`. Concentrate on completeing the
  `create_users` section with all the users that should have access to the nodes and their `public_keys` they will use.
* `MAIN_TF_FILE`: Containing the completed contents of `terraform/env/{devel,prod,shared}/main.tf.example` (remember, this can be a scoped variable)

#### MSUL Users
The user running the pipeline needs to have access to read from the following repositories:  
* (optional) [playbook-ubuntu-setup](https://gitlab.msu.edu/msu-libraries/devops/playbook-ubuntu-setup)
    * This is an optional stage in the pipleine and not required.
    * This requires the public key for the `ROOT_PRIVATE_KEY` to be manually added to the
      `ubuntusetup` user's authorized keys file on the `ansible.lib.msu.edu` server for the CI to connect.
    * The CI will connect with that key but then from the `ansible.lib.msu.edu` server it will connect
      to the catalog nodes as the `ansible` user using the key created in the `user_data.sh` script in Terraform
      (the public key is passed in via the Terraform environment definitions and the private key is stored only
      on the `ansible.lib.msu.edu` server in the `ansible` user's `.ssh` directory.

### Deploy User Setup
A deploy key has been created and it's public key is stored in the `configure-playbook/variables.yml` CI variable, `VARIABLE_YAML_FILE` with
a corresponding private key in the CI/CD variables of the
[catalog project's repository](https://gitlab.msu.edu/msu-libraries/catalog/catalog/-/settings/ci_cd). Should that key ever need to change,
both locations will need to be updated in the `DEPLOY_PRIVATE_KEY` variable there.

This key is used in this repository when
the `configure-playbook` is run and is setting up users; it will setup the authorized key entry for that public key
on the `deploy` user. Then the [catalog repository](https://github.com/MSU-Libraries/catalog) uses that when
it connects to the codes as the deploy user to deploy the Docker stacks.

### Terraform Setup
This repository contains 3 Terraform environments: shared, devel, and prod. The shared one represents
shared resources accross all the clusters, such as the storage. Those resources must be created first before
either devel or prod are created.

The 3 environments we have created in this repository represent specific settings that made sense for us.
To make your own cluster, you will want to copy the shared environment and the devel and/or prod directories
and start modifying them. Here are the values you are most likely going to want to change in each:

**Shared**
* `terraform`
  * `backend "s3"`: This identifies where the Terraform state file is stored, you'll want to make this a
    bucket and key specific to you
* `module "shared"`
  * `alert_emails`: What distribution list will receive alert emails from AWS
  * `domain`: The domain to create the resources in
  * `zone_id`: The DNS zone ID in Route53 that the `domain` is associated with
* `module "cluster"`
  * `root_public_key`: Public SSH key for the root user on the nodes created earlier in the `ROOT_PRIVATE_KEY`
  * `ansible_public_key`: Public SSH key for the ansible server that will run ubuntu-setup-playbook.
    This is MSUL specific and should be left blank for other users.
  * `net_allow_inbound_ssh`: CIDR range that allows connections from port 22 (ssh)
  * `net_allow_inbound_ncpa`: CIDR range that allows connections from port 5693 (for Nagios NCPA monitoring)
  * `net_allow_inbound_web`: CIDR range that allows connections from port 443 and 80
  * `roundrobin_hostnames`: DNS names that you want created to resolve to one of the 3 nodes in the cluster
  * `nodes`
      * `server_name`: Name of the server in the cluster
      * `aws_ami`: The AWS AMI for the instance you want to create (this is like the VM image tag)
      * `aws_instance_type`: Type of EC2 instance to create
      * `aws_root_block_size`: Size of the root partition of the node
      * `cpu_balance_threshold`: What CPU credit balance threshold must be met for an alert to be sent
      * `ebs_balance_threshold`: What percentage threshold of the burst balance for an alert to be sent

Also of note, we have two cases where we have `prevent_destroy` set to avoid accidently destroying critical
resources (our EFS share and the EC2 instances), such as a bad commit in a CI deploy. But if you are testing
and want to be able to remove those, you will need to look for those references and set it to `false`.

### DNS Setup
Since this terraform playbook only creates DNS entries in the `.aws.lib.msu.edu`
domain (see the `domain` variable in the terraform files), and we want our site
to be accessible at `catalog.lib.msu.edu` (and not just `catalog.aws.lib.msu.edu`), we need to create CNAME
entries in our local DNS server that point to the ones that AWS created.

For example, we have the following CNAME records:

| Name                  | Type          | Target                       |
|-----------------------|---------------|------------------------------|
| catalog               | Alias (CNAME) | catalog.aws.lib.msu.edu.     |
| catalog-beta          | Alias (CNAME) | catalog.aws.lib.msu.edu.     |
| catalog-preview       | Alias (CNAME) | catalog.aws.lib.msu.edu.     |
| catalog-prod          | Alias (CNAME) | catalog.aws.lib.msu.edu.     |

## How To Guides

### Manually run terraform commands

```bash
# Change directory to the environment you want to apply changes to
cd terraform/env/prod

# Preview Changes
terraform plan

# Apply Changes
terraform apply

# Take down the server cluster and all resources associated with it
terraform destroy

# Re-initialize new cluster if a node is re-created without removing from swarm first
docker swarm init --force-new-cluster 
```

### Increasing node root partition size
Increasing the size of the root EBS block, used for the root file-system, can
be done relatively quickly and without requiring a reboot.

1. Increase the `aws_root_block_size` (GB) for each node in `terraform/env/prod/main.tf`
2. Commit and push to `main` branch. This will trigger `terraform` to perform the disk expansion via the CI pipeline.
    - You could also manually run `terraform apply` on `terraform/env/prod/`; just be sure to commit and push afterwards.
3. On each node:
    - Expand the partition table. This can be done via:
      ```
      parted --list
      # When prompted to Fix/Ignore, choose fix
      Warning: Not all of the space available to /dev/nvme0n1 appears to be used, you
      can fix the GPT to use all of the space (an extra 402653184 blocks) or continue
      with the current setting?
      Fix/Ignore? fix
      ```
    - Expand the root partition (typically partition 1; see output of previous command):
      ```
      parted /dev/nvme0n1
      # Will take you to parted prompt
      (parted) resizepart
      Partition number? 1
      Warning: Partition /dev/nvme0n1p1 is being used. Are you sure you want to continue?
      Yes/No? yes
      End?  [68.7GB]? 100%
      (parted) quit
      ```
    - Expand the ext4 file-system to use 100% of the partition (default action for `resize2fs`):
      ```
      resize2fs /dev/nvme0n1p1
      ```

At this point the file-system should be expanded. Verify via `df -h`.

### Force recreation of a node
NOTE: This whole process takes about 10-15 minutes.
 
* Leave the swarm
```
# Run this on the node
docker swarm leave

# Run this on this on another node
docker node rm --force [name/ID]
```

* Use terraform to replace the node
```
# Got to the directory of the environment with the node you want to replace
cd terraform/env/prod

# This example is replacing node "c"
terraform apply -replace='module.catalog.module.nodes["c"].aws_instance.node_instance'
```
* Use the AWS console (or be patient) to confirm the new node is ready
You can confirm the new node is ready in the EC2 console by viewing the system logs for the instance.
This typically takes 5-10 minutes. Or of course, you could just wait that amount of time and skip to the
next step hoping for the best!

* Re-run the last successful provision pipeline
This step is required as it will run the playbooks required to configure the newly created node.

### Mounting the Shared Storage
To mount the shared storage (`/mnt/shared/local` on the nodes) on your local machine, use
the credentials for the same user as used by Solr and the Traefik Dashboard). To mount,
we will be making use of the `sshfs` tool.

For more information on this share see the
[technical documentation](https://msu-libraries.github.io/catalog/first-time-setup/#for-local-development).

**Permissions on Server**  
The shared storage on the server will need to be writable by the connecting user. For example, if the
storage us group writable by the `ubuntu` user, the user on the server will needt o be in the `ubuntu`
group. This can be done by adding the group to the user in `configure-playbook/variables.yml` CI
variable, `VARIABLE_YAML_FILE` and then triggering the CI process.
```
 - name: myuser
   comment: 'Myu Ser'
   groups: ubuntu
   public_keys:
```

#### MacOS
Mac users will require macFUSE and sshfs to be installed separately before continuing.
The latest release is available on the [osxfuse GitHub site](https://osxfuse.github.io/).

Locally on the Mac mounting the share, you'll have to make it think it also has permissions to write.
For example, if the server has the `ubunbu` group as writable with gid of `1000`, you'll need to
configure you Mac to also have a group with gid `1000` that your user

To create the new group and add your user `myuser`:
```sh
# Create group ubuntu with gid 1000
sudo dscl . -create /groups/ubuntu gid 1000
# Add user myuser to ubuntu group
sudo dscl . -append /Groups/ubuntu GroupMembership myuser
```

From there you should be able to create a directory to mount from and mount as your normal user (no `sudo`):
```sh
# Only need to create the directory the first time
mkdir ~/my-sshfs

sshfs -o allow_other,default_permissions myuser@catalog-1.aws.lib.msu.edu:/mnt/shared/local ~/my-sshfs
```

To unmount:
```sh
umount ~/my-sshfs 
```

#### Linux
Before attempting to mount, you will need `sshfs`. To install:
```bash
$ sudo apt install sshfs
```

Here is an example of mounting the share (to and example `/mnt/point/` directory) for a single time (not auto-remounted):
```bash
sudo sshfs -o allow_other,default_permissions [netid]@catalog-1.aws.lib.msu.edu:/mnt/shared/local /mnt/point
```

Here is an example of an `/etc/fstab` entry for mounting it:
```bash
[netid]@catalog-1.aws.lib.msu.edu:/mnt/shared/local /mnt/point fuse.sshfs noauto,x-systemd.automount,_netdev,reconnect,identityfile=/home/[netid]/.ssh/id_ed25519,allow_other,default_permissions 0 0
```

To mount:
```bash
$ sudo mkdir -p /mnt/catalog
$ sudo mount /mnt/catalog
$ sudo umount /mnt/catalog
```

## Troubleshooting

### Traefik Let's Encrypt certificates not renewing automatically

Traefik runs as host network mode on each node and DNS is normally configured to round robin between all nodes on a cluster.
This can lead to the situation where the Let's Encrypt certificate fails to renew before expiration
due to the round robin DNS not resolving to the correct node when performing a HTTP challenge.

This issue is something we have on our radar to investigate further and find a workaround for, but in
the mean time it may require a manual intervention to get the certificates to renew before expiration.

For context, Let's Encrypt certificates last for 3 months. They normally attempt to renew after 2 months have expired. If a certificate isn't over 2 months old, Traefik will not attempt to renew it.

To trigger the Let's Encrypt renewal process within Traefik to succeed for a given node (we'll
use `catalog-beta.lib.msu.edu` for the certificate hostname and `catalog-2.aws.lib.msu.edu` for the
node in this example):

* Change DNS for the hostname to the node where the certificate needs to be updated in your local DNS. In our case this is Libraries Windows DNS (manual process, requires Systems unit sysadmin to make change)
  * Example: Update `catalog-beta.lib.msu.edu` from the round robin production DNS of `catalog.aws.lib.msu.edu` to the specific node DNS of `catalog-2.aws.lib.msu.edu`
* If needing to update certs on multiple nodes, or to speed the DNS change back once completed, also reduce the DNS TTL for the record to 1 minute
* Wait several minutes longer than the original TTL (up to 10 more in some cases) to let DNS changes propagate
  * If the original TTL was 5 minutes, you may need to wait 10 to 15 minutes
* Connect to the node in question and `docker stop` the `traefik_traefik.xyz...` container to force it to restart; restarting Traefik will make it perform a new challenge attempt right away
  * Example: `ssh catalog-2.aws.lib.msu.edu` and `docker stop traefik_traefik.yqeqk81ltw.kaawo44qqtu`
* Wait up to two minutes for Traefik to start and the Let's Encrypt challange to complete
* Verify the new certificate is visible for the host
  * Beware using a browser to verify, as they like to cache everything; consider using the command line.
  * Example: `echo | openssl s_client -servername catalog-beta.lib.msu.edu -connect catalog-2.aws.lib.msu.edu:443 2>/dev/null | openssl x509 -nokeys -dates | head -n2`
    * Note in the above command where it the certificate hostname _and_ the node hostname are set
* If cert if not updated, be patient (10+ minutes) and try again restarting the Traefik container
* Once the new certificate is verified, proceed to change DNS to update any other certs than need manual assistance
* Once all certificates are okay, change DNS back to the round robin configuration and prior TTL
  * Example: Update `catalog-beta.lib.msu.edu` back to `catalog.aws.lib.msu.edu` with a TTL of 5 minutes

That should be all that's required.
