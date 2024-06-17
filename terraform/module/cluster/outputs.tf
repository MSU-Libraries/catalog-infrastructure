output "aws_region" {
    description = "The AWS region used"
    value       = "${var.aws_region}"
}

# Traefik DNS challenge user keys
output "dnschallenge_key_id" {
    description = "The AWS access key id for the dnschallenge user"
    value       = "${aws_iam_access_key.dnschallenge_key.id}"
}

output "dnschallenge_key_secret" {
    description = "The AWS secret access key for the dnschallenge user"
    value       = "${aws_iam_access_key.dnschallenge_key.secret}"
    sensitive   = true
}

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
