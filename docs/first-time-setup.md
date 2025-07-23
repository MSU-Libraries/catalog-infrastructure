# First time setup

## AWS User Setup
An AWS user is required and will need to have multiple access roles granted to it in IAM
to perform the tasks required in Terraform. Below outline the permissions required on the group
the AWS user is attached to:  

Policy: `AmazonEC2FullAccess`  
[Custom Policy](https://github.com/MSU-Libraries/catalog-infrastructure/blob/main/user-policy.json)

If you are using the above IAM policy as a template for yourself, be sure to modify any IDs
or resource names as needed (some are specifically named `msul`).  

Save the AWS Key and Secret for this user to be set in the GitLab CI/CD variables.

## GitLab Setup
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
* `GITHUB_USER_TOKEN`: Token used to publish releases to GitHub repository
* `VARIABLES_YAML_FILE`:  Containing the completed contents of the  `configure-playbook/variables.yml.example`
  file leaving in `$` variable references like `REGISTRY_ACCESS_TOKEN`. Concentrate on completeing the
  `create_users` section with all the users that should have access to the nodes and their `public_keys` they will use.
* `MAIN_TF_FILE`: Containing the completed contents of `terraform/env/{devel,prod,shared}/main.tf.example` (remember, this can be a scoped variable)
* `RW_CICD_TOKEN`: Read-Write access token to this repository used to create release tags

### MSUL Users
The user running the pipeline needs to have access to read from the following repositories:

* (optional) [playbook-ubuntu-setup](https://gitlab.msu.edu/msu-libraries/devops/playbook-ubuntu-setup)
    * This is an optional stage in the pipleine and not required.
    * This requires the public key for the `ROOT_PRIVATE_KEY` to be manually added to the
      `ubuntusetup` user's authorized keys file on the `ansible.lib.msu.edu` server for the CI to connect.
    * The CI will connect with that key but then from the `ansible.lib.msu.edu` server it will connect
      to the catalog nodes as the `ansible` user using the key created in the `user_data.sh` script in Terraform
      (the public key is passed in via the Terraform environment definitions and the private key is stored only
      on the `ansible.lib.msu.edu` server in the `ansible` user's `.ssh` directory.

## Deploy User Setup
A deploy key has been created and it's public key is stored in the `configure-playbook/variables.yml` CI variable, `VARIABLE_YAML_FILE` with
a corresponding private key in the CI/CD variables of the
[catalog project's repository](https://gitlab.msu.edu/msu-libraries/catalog/catalog/-/settings/ci_cd). Should that key ever need to change,
both locations will need to be updated in the `DEPLOY_PRIVATE_KEY` variable there.

This key is used in this repository when
the `configure-playbook` is run and is setting up users; it will setup the authorized key entry for that public key
on the `deploy` user. Then the [catalog repository](https://github.com/MSU-Libraries/catalog) uses that when
it connects to the codes as the deploy user to deploy the Docker stacks.

## Terraform Setup
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

## DNS Setup
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
