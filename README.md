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

