terraform {
    backend "s3" {
        bucket = "msulib-catalog-terraform-states"
        key    = "catalog/catalog-test.tfstate"
        region = "us-east-2"
    }
}

module "mail" {
  source = "../../module/mail_smtp"
  aws_region = "us-east-1"
  mail_instance = "catalog-test"
}

module "catalog_test" {
  source = "../../module/catalog"
  server_name = "catalog-test"
  aws_region = "us-east-1"
  aws_availability_zone = "a"
  aws_ami = "ami-052efd3df9dad4825"
  smtp_host = module.mail.smtp_host
  smtp_user = module.mail.smtp_username
  smtp_password = module.mail.smtp_password
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

output "test_instance_id" {
  value = module.catalog_test.instance_id
}

output "test_public_ip" {
  value = module.catalog_test.public_ip
}
