# Created instance id after provisioning
output "instance_id" {
  description = "AWS Instance ID"
  value       = aws_instance.node_instance.id
}

# Domain name of machine created during provisioning
output "fqdn" {
  description = "AWS Instance Hostname"
  value       = aws_route53_record.node_dnsrec.fqdn
}

# The public IP assigned during provisioning
output "public_ip" {
  description = "AWS Instance Public IP"
  value       = aws_eip.node_eip.public_ip
}

# The shared EFS mount hostname
output "efs_hostname" {
  description = "AWS EFS Mount Target Hostname"
  value       = aws_efs_mount_target.catalog_efs_mt.mount_target_dns_name
}
