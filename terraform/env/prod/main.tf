terraform {
    backend "s3" {
        bucket = "msulib-terraform-states"
        key    = "catalog/catalog-prod.tfstate"
        region = "us-east-2"
    }
}

module "mail" {
  source = "../../module/mail_smtp"
  aws_region = "us-east-1"
  mail_instance = "catalog-prod"
}

module "catalog" {
  source = "../../module/catalog"
  cluster_name = "catalog"
  aws_region = "us-east-1"
  vpc_cidr = "10.1.0.0/16"
  smtp_host = module.mail.smtp_host
  smtp_user = module.mail.smtp_username
  smtp_password = module.mail.smtp_password
  net_allow_inbound_ssh = [
    "35.8.220.0/22",
  ]
  net_allow_inbound_ncpa = [
    "35.8.220.0/22",
  ]
  net_allow_inbound_web = [
    "0.0.0.0/0",
  ]
  nodes = {
    "a" = {
      server_name = "catalog-a"
      aws_availability_zone = "a"
      aws_ami = "ami-052efd3df9dad4825"
      aws_instance_type = "t3a.large"
      aws_root_block_size = 16
      private_ip = "10.1.1.10"
      subnet_cidr = "10.1.1.0/24"
    }
    "b" = {
      server_name = "catalog-b"
      aws_availability_zone = "b"
      aws_ami = "ami-052efd3df9dad4825"
      aws_instance_type = "t3a.large"
      aws_root_block_size = 16
      private_ip = "10.1.2.10"
      subnet_cidr = "10.1.2.0/24"
    }
    "c" = {
      server_name = "catalog-c"
      aws_availability_zone = "c"
      aws_ami = "ami-052efd3df9dad4825"
      aws_instance_type = "t3a.large"
      aws_root_block_size = 16
      private_ip = "10.1.3.10"
      subnet_cidr = "10.1.3.0/24"
    }
  }
}

output "catalog_a_instance_id" {
  value = module.catalog.instance_ids[0]
}

output "catalog_a_fqdn" {
  value = module.catalog.fqdns[0]
}

output "catalog_a_public_ip" {
  value = module.catalog.public_ips[0]
}

output "catalog_b_instance_id" {
  value = module.catalog.instance_ids[1]
}

output "catalog_b_fqdn" {
  value = module.catalog.fqdns[1]
}

output "catalog_b_public_ip" {
  value = module.catalog.public_ips[1]
}

output "catalog_c_instance_id" {
  value = module.catalog.instance_ids[2]
}

output "catalog_c_fqdn" {
  value = module.catalog.fqdns[2]
}

output "catalog_c_public_ip" {
  value = module.catalog.public_ips[2]
}
