# Created instance id after provisioning
output "instance_ids" {
  description = "AWS Instance IDs"
  value       = [
    for n in module.nodes : n.instance_id
  ]
}

# Domain name of machine created during provisioning
output "fqdns" {
  description = "AWS Instance FQDNs"
  value       = [
    for n in module.nodes : n.fqdn
  ]
}

# The public IP assigned during provisioning
output "public_ips" {
  description = "AWS Instance Public IPs"
  value       = [
    for n in module.nodes : n.public_ip
  ]
}
