terraform {
    backend "s3" {
        bucket = "msulib-terraform-states"
        key    = "catalog/cluster-devel.tfstate"
        region = "us-east-2"
    }
}

variable "vpc_cidr" {
  description = "CIDR range to be used for AWS VPC"
  type = string
}

variable "vpc_id" {
  description = "The vpc.id where to place the cluster"
  type = string
}

variable "zone_subnet_ids" {
  description = "Subnet IDs for each availability zone"
  type = list(string)
}

variable "alert_topic_arn" {
  description = "SNS topic ARN to send alerts to"
  type = string
}

variable "efs_security_group_id" {
  description = "The security group id to allow access to EFS mount"
  type = string
}

variable "efs_mount_hostnames" {
  description = "EFS mount target hostnames for each availability zone"
  type = list(string)
}

variable "smtp_host" {
  description = "SMTP hostname"
  type = string
}

variable "smtp_username" {
  description = "SMTP username"
  type = string
}

variable "smtp_password" {
  description = "SMTP password"
  type = string
}

variable "domain" {
  # example: aws.lib.msu.edu
  description = "The domain within which the servers will reside"
  type = string
}

variable "zone_id" {
  # example: Z01234567890ABCDEFGHI
  description = "The zone_id in AWS Route53 for which the domain is associated"
  type = string
}

module "cluster" {
  source = "../../module/cluster"
  cluster_name = "catalog-devel"
  aws_region = "us-east-1"
  vpc_cidr = var.vpc_cidr
  vpc_id = var.vpc_id
  domain = var.domain
  zone_id = var.zone_id
  alert_topic_arn = var.alert_topic_arn
  efs_security_group_id = var.efs_security_group_id
  smtp_host = var.smtp_host
  smtp_user = var.smtp_username
  smtp_password = var.smtp_password
  root_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPEqI2N91B6/W5RA5OsgDmfn0OWBUSLUcRPQhZhuU/Ex root @ catalog nodes"
  ansible_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIChaBRQuzsZVT4S2/yYiahfam7IDAVx42YJOoOpc2fYy ansible@ansible.lib.msu.edu"
  net_allow_inbound_ssh = [
    "0.0.0.0/0",
  ]
  net_allow_inbound_ssh_alt = [
    "0.0.0.0/0",
  ]
  net_allow_inbound_ncpa = [
    "35.8.220.0/22",
  ]
  net_allow_inbound_web = [
    "35.8.220.0/22",
  ]
  roundrobin_hostnames = [
    "catalog-dev",
  ]
  nodes = {
    "a" = {
      server_name = "catalog-1-dev"
      aws_availability_zone = "a"
      aws_ami = "ami-052efd3df9dad4825"
      aws_instance_type = "t3a.xlarge"
      aws_root_block_size = 100
      cpu_balance_threshold = 1728      # max of 2304 for t3a.xlarge
      ebs_balance_threshold = 75        # percentage of max
      private_ip = "10.1.1.138"
      subnet_id = var.zone_subnet_ids[0]
      domain = var.domain
      zone_id = var.zone_id
    }
    "b" = {
      server_name = "catalog-2-dev"
      aws_availability_zone = "b"
      aws_ami = "ami-052efd3df9dad4825"
      aws_instance_type = "t3a.xlarge"
      aws_root_block_size = 100
      cpu_balance_threshold = 1728      # max of 2304 for t3a.xlarge
      ebs_balance_threshold = 75        # percentage of max
      private_ip = "10.1.2.138"
      subnet_id = var.zone_subnet_ids[1]
      domain = var.domain
      zone_id = var.zone_id
    }
    "c" = {
      server_name = "catalog-3-dev"
      aws_availability_zone = "c"
      aws_ami = "ami-052efd3df9dad4825"
      aws_instance_type = "t3a.xlarge"
      aws_root_block_size = 100
      cpu_balance_threshold = 1728      # max of 2304 for t3a.xlarge
      ebs_balance_threshold = 75        # percentage of max
      private_ip = "10.1.3.138"
      subnet_id = var.zone_subnet_ids[2]
      domain = var.domain
      zone_id = var.zone_id
    }
  }
}

output "aws_region" {
  description = "AWS region being used"
  value       = module.cluster.aws_region
}

output "dnschallenge_key_id" {
  description = "DNS challenge key id"
  value       = module.cluster.dnschallenge_key_id
}

output "dnschallenge_key_secret" {
  description = "DNS chanllege key secret"
  value       = module.cluster.dnschallenge_key_secret
  sensitive   = true
}

output "catalog_a_instance_id" {
  description = "Instance ID (catalog-1)"
  value = module.cluster.instance_ids[0]
}

output "catalog_a_fqdn" {
  description = "FQDN (catalog-1)"
  value = module.cluster.fqdns[0]
}

output "catalog_a_public_ip" {
  description = "Public IP (catalog-1)"
  value = module.cluster.public_ips[0]
}

output "catalog_a_efs_hostname" {
  description = "AWS EFS hostname (catalog-1)"
  value = var.efs_mount_hostnames[0]
}

output "catalog_b_instance_id" {
  description = "Instance ID (catalog-2)"
  value = module.cluster.instance_ids[1]
}

output "catalog_b_fqdn" {
  description = "FQDB (catalog-2)"
  value = module.cluster.fqdns[1]
}

output "catalog_b_public_ip" {
  description = "Public IP (catalog-2)"
  value = module.cluster.public_ips[1]
}

output "catalog_b_efs_hostname" {
  description = "AWS EFS hostname (catalog-2)"
  value = var.efs_mount_hostnames[1]
}

output "catalog_c_instance_id" {
  description = "Instance ID (catalog-3)"
  value = module.cluster.instance_ids[2]
}

output "catalog_c_fqdn" {
  description = "FQDN (catalog-3)"
  value = module.cluster.fqdns[2]
}

output "catalog_c_public_ip" {
  description = "Public IP (catalog-3)"
  value = module.cluster.public_ips[2]
}

output "catalog_c_efs_hostname" {
  description = "AWS EFS hostname (catalog-3)"
  value = var.efs_mount_hostnames[2]
}

