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

variable "route_table_id" {
  description = "The route table id for the VPC"
  type = string
}

variable "efs_id" {
  description = "The efs.id for the mounted shared storage within the servers"
  type = string
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

module "cluster" {
  source = "../../module/cluster"
  cluster_name = "catalog-devel"
  aws_region = "us-east-1"
  vpc_cidr = var.vpc_cidr
  vpc_id = var.vpc_id
  route_table_id = var.route_table_id
  efs_id = var.efs_id
  cluster_cidr = "10.1.16.0/20"
  domain = "aws.lib.msu.edu"
  zone_id = "Z0159018169CCNUQINNQG"
  smtp_host = var.smtp_host
  smtp_user = var.smtp_username
  smtp_password = var.smtp_password
  net_allow_inbound_ssh = [
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
      private_ip = "10.1.17.10"
      subnet_cidr = "10.1.17.0/24"
    }
    "b" = {
      server_name = "catalog-2-dev"
      aws_availability_zone = "b"
      aws_ami = "ami-052efd3df9dad4825"
      aws_instance_type = "t3a.xlarge"
      aws_root_block_size = 100
      private_ip = "10.1.18.10"
      subnet_cidr = "10.1.18.0/24"
    }
    "c" = {
      server_name = "catalog-3-dev"
      aws_availability_zone = "c"
      aws_ami = "ami-052efd3df9dad4825"
      aws_instance_type = "t3a.xlarge"
      aws_root_block_size = 100
      private_ip = "10.1.19.10"
      subnet_cidr = "10.1.19.0/24"
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
  value = module.cluster.efs_hostnames[0]
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
  value = module.cluster.efs_hostnames[1]
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
  value = module.cluster.efs_hostnames[2]
}

