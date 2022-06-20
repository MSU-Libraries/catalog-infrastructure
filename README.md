# Catalog Infrastructure
Public catalog infrastructure files using Terraform to build
a server cluster on AWS.

```
cd env/prod

# Preview Changes
terraform plan

# Apply Changes
terraform apply

# Take down the server cluster and all resources associated with it
terraform destroy
```


## Planning

* Add in a shared network for the 3 servers in the cluster to share
* Have CI-CD kick off an Ansible playbook that will run `terraform apply` in a "safe"
manner (i.e. won't destroy before creating) and then perform the rest of the server set-up
