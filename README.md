# Catalog Infrastructure
Public catalog infrastructure files using Terraform to build
a server cluster on AWS.


## First time setup

### AWS User Setup
An AWS user is required and will need to have multiple access roles granted to it in IAM
to perform the tasks required in Terraform. Below outline the permissions required on the group
the AWS user is attached to:

Policy: `AmazonEC2FullAccess`
[Custom Policy](user-policy.json)

### GitLab Setup
The user running the pipeline needs to have access to read from the following repositories:  
* [playbook-ubuntu-setup](https://gitlab.msu.edu/msu-libraries/devops/playbook-ubuntu-setup)
* [playbook-conditional-reboot](https://gitlab.msu.edu/msu-libraries/systems/playbook-conditional-reboot)

The following CI/CD variables must also be created: 
* `AWS_KEY`
* `AWS_SECRET`
* `ROOT_PRIVATE_KEY`
* `SAMBA_PASS`

### Deploy User setup
A deploy key has been created and it's public key is stored in the `configure-playbook/variables.yml` file with 
a corresponding private key in the CI/CD variables of the
[catalog project's repository](https://gitlab.msu.edu/msu-libraries/devops/catalog). Should that key ever need to change,
both locations will need to be updated.


## Troubleshooting
Manual steps:
```
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

### To force recreation of a node:
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

