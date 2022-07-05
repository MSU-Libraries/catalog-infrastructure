# Catalog Infrastructure
Public catalog infrastructure files using Terraform to build
a server cluster on AWS.


## First time setup

### AWS User Setup
An AWS user is required and will need to have multiple access roles granted to it in IAM
to perform the tasks required in Terraform. Below outline the permissions required:

TODO

### Deploy User setup
A deploy key has been created and it's public key is stored in the `configure-playbook/variables.yml` file with 
a corresponding private key in the CI/CD variables of the
[catalog project's repository](https://gitlab.msu.edu/msu-libraries/devops/catalog). Should that key ever need to change,
both locations will need to be updated.


## Troubleshooting
Manual steps:
```
cd env/prod

# Preview Changes
terraform plan

# Apply Changes
terraform apply

# Take down the server cluster and all resources associated with it
terraform destroy
```
