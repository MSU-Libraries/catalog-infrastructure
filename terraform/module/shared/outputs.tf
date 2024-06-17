output "smtp_host" {
  description = "SMTP server host to connect to for given AWS region"
  value       = "email-smtp.${var.aws_region}.amazonaws.com"
}

# The SMTP username used for sending email via SES
output "smtp_username" {
  description = "User for sending SMTP email"
  value       = aws_iam_access_key.catalog_smtp_key.id
}

# The SMTP password used for sending email via SES
output "smtp_password" {
  description = "Password for sending SMTP email"
  value       = aws_iam_access_key.catalog_smtp_key.ses_smtp_password_v4
  sensitive   = true
}

output "vpc_cidr" {
  description = "Returning the VPC CIDR that was passed in"
  value       = var.vpc_cidr
}

output "vpc_id" {
  description = "The created vpc.id"
  value       = aws_vpc.shared_vpc.id
}

output "zone_subnet_ids" {
  description = "Subnet IDs for each availability zone"
  value       = [
    for s in aws_subnet.zone_subnets : s.id
  ]
}

output "efs_security_group_id" {
  description = "The security group id to allow access to EFS mount"
  value       = aws_security_group.security_group_efs_net.id
}

output "efs_mount_hostnames" {
  description = "Mount target hostnames for EFS use in each availability zone"
  value       = [
    for t in aws_efs_mount_target.shared_efs_mts : t.mount_target_dns_name
  ]
}
