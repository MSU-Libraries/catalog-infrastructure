terraform {
    backend "s3" {
        bucket = "msulib-terraform-states"
        key    = "catalog/shared.tfstate"
        region = "us-east-2"
    }
}

module "shared" {
  source          = "../../module/shared"
  aws_region      = "us-east-1"
  mail_instance   = "catalog-prod"
  shared_name     = "catalog"
  vpc_cidr        = "10.1.0.0/16"
  efs_mount_zones = ["a", "b", "c"]
}

output "smtp_host" {
  description = "Hostname for SES SMTP access"
  value       = module.shared.smtp_host
}

output "smtp_username" {
  description = "Username for SES SMTP access"
  value       = module.shared.smtp_username
}

output "smtp_password" {
  description = "Password for SES SMTP access"
  value       = module.shared.smtp_password
  sensitive   = true
}

output "vpc_cidr" {
  description = "The CIDR for the VPC, the same as passed variable input"
  value       = module.shared.vpc_cidr
}

output "vpc_id" {
  description = "The created vpc.id"
  value       = module.shared.vpc_id
}

output "efs_security_group_id" {
  description = "The security group id to allow access to EFS mount"
  value       = module.shared.efs_security_group_id
}

output "efs_mount_hostnames" {
  description = "EFS mount target hostnames for each availability zone"
  value       = module.shared.efs_mount_hostnames
}

output "route_table_id" {
  description = "The route table id for the VPC"
  value       = module.shared.route_table_id
}
