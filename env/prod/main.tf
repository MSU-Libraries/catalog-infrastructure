terraform {
    backend "s3" {
        bucket = "msulib-catalog-terraform-states"
        key    = "catalog/catalog-prod.tfstate"
        region = "us-east-2"
    }
}

module "catalog_a" {
  source = "../../module/catalog"
  server_name = "catalog-a"
  aws_region = "us-east-1"
  aws_availability_zone = "a"
  aws_ami = "ami-052efd3df9dad4825"
  aws_instance_type = "t3a.large"
  aws_root_block_size = 16
  net_allow_inbound_ssh = [
    "35.8.220.0/22",
  ]
  net_allow_inbound_ncpa = [
    "35.8.220.0/22",
  ]
  net_allow_inbound_web = [
    "0.0.0.0/0",
  ]
}

module "catalog_b" {
  source = "../../module/catalog"
  server_name = "catalog-b"
  aws_region = "us-east-1"
  aws_availability_zone = "b"
  aws_ami = "ami-052efd3df9dad4825"
  aws_instance_type = "t3a.large"
  aws_root_block_size = 16
  net_allow_inbound_ssh = [
    "35.8.220.0/22",
  ]
  net_allow_inbound_ncpa = [
    "35.8.220.0/22",
  ]
  net_allow_inbound_web = [
    "0.0.0.0/0",
  ]
}

module "catalog_c" {
  source = "../../module/catalog"
  server_name = "catalog-c"
  aws_region = "us-east-1"
  aws_availability_zone = "c"
  aws_ami = "ami-052efd3df9dad4825"
  aws_instance_type = "t3a.large"
  aws_root_block_size = 16
  net_allow_inbound_ssh = [
    "35.8.220.0/22",
  ]
  net_allow_inbound_ncpa = [
    "35.8.220.0/22",
  ]
  net_allow_inbound_web = [
    "0.0.0.0/0",
  ]
}

output "catalog_a_instance_id" {
  value = module.catalog_a.instance_id
}

output "catalog_a_public_ip" {
  value = module.catalog_a.public_ip
}

output "catalog_b_instance_id" {
  value = module.catalog_b.instance_id
}

output "catalog_b_public_ip" {
  value = module.catalog_b.public_ip
}

output "catalog_c_instance_id" {
  value = module.catalog_c.instance_id
}

output "catalog_c_public_ip" {
  value = module.catalog_c.public_ip
}
