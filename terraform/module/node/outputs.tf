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
