# Created instance id after provisioning
output "instance_id" {
  description = "AWS Instance ID"
  value       = aws_instance.catalog_instance.id
}

# The public IP assigned during provisioning
output "public_ip" {
  description = "AWS Instance Public IP"
  value       = aws_eip.catalog_eip.public_ip
}
