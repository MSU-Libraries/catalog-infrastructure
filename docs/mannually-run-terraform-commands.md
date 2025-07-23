# Manually run terraform commands

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
