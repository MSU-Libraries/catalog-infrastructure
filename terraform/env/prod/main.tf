terraform {
    backend "s3" {
        bucket = "msulib-catalog-terraform-states"
        key    = "catalog/catalog-prod.tfstate"
        region = "us-east-2"
    }
}

module "shared" {
  source = "../../module/shared"
  aws_region = "us-east-1"
  mail_instance = "catalog-prod"
}

moved {
    from = module.mail
    to   = module.shared
}

module "cluster" {
  source = "../../module/cluster"
  cluster_name = "catalog"
  aws_region = "us-east-1"
  vpc_cidr = "10.1.0.0/16"
  #cluster_cidr = "10.1.1.10/22" # TODO change this value somehow
  #domain = "aws.lib.msu.edu"
  #zone_id = "Z0159018169CCNUQINNQG"
  smtp_host = module.shared.smtp_host
  smtp_user = module.shared.smtp_username
  smtp_password = module.shared.smtp_password
  net_allow_inbound_ssh = [
    "0.0.0.0/0",
  ]
  net_allow_inbound_ncpa = [
    "35.8.220.0/22",
  ]
  net_allow_inbound_web = [
    "0.0.0.0/0",
  ]
  nodes = {
    "a" = {
      server_name = "catalog-1"
      aws_availability_zone = "a"
      aws_ami = "ami-052efd3df9dad4825"
      aws_instance_type = "t3a.2xlarge"
      aws_root_block_size = 384
      private_ip = "10.1.1.10"
      subnet_cidr = "10.1.1.0/24"
    }
    "b" = {
      server_name = "catalog-2"
      aws_availability_zone = "b"
      aws_ami = "ami-052efd3df9dad4825"
      aws_instance_type = "t3a.2xlarge"
      aws_root_block_size = 384
      private_ip = "10.1.2.10"
      subnet_cidr = "10.1.2.0/24"
    }
    "c" = {
      server_name = "catalog-3"
      aws_availability_zone = "c"
      aws_ami = "ami-052efd3df9dad4825"
      aws_instance_type = "t3a.2xlarge"
      aws_root_block_size = 384
      private_ip = "10.1.3.10"
      subnet_cidr = "10.1.3.0/24"
    }
  }
}

moved {
    from = module.catalog
    to   = module.cluster
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

