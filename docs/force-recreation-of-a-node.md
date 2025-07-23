# Force recreation of a node
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
